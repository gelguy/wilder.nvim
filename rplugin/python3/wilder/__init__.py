import asyncio
import concurrent.futures
import fnmatch
import functools
import glob
import importlib
from importlib.util import find_spec
import multiprocessing
import os
from pathlib import Path
import pwd
import shutil
import threading
import time


if find_spec('pynvim'):
    import pynvim as neovim
else:
    import neovim

@neovim.plugin
class Wilder(object):
    def __init__(self, nvim):
        self.nvim = nvim
        self.has_init = False
        self.queue = multiprocessing.Queue()
        self.events = []
        self.lock = threading.Lock()
        self.executor = None

    def handle(self, ctx, x, command='resolve'):
        self.nvim.call('wilder#pipeline#' + command, ctx, x)

    def echo(self, x):
        self.nvim.session.threadsafe_call(lambda: self.nvim.command('echomsg "' + x + '"'))

    def run_in_background(self, fn, args):
        self.executor.submit(functools.partial( fn, *args, ))

    def consumer(self):
        while True:
            args = self.queue.get()

            ctx = args[0]
            res = args[1]
            while not self.queue.empty():
                new_args = self.queue.get_nowait()
                new_ctx = new_args[0]

                if (new_ctx['run_id'] > ctx['run_id'] or
                        (new_ctx['run_id'] == ctx['run_id'] and new_ctx['step'] > ctx['step'])):
                    args = new_args
                    ctx = args[0]
                    res = args[1]

            if len(args) > 2:
                command = args[2]
                self.nvim.async_call(self.handle, ctx, res, command=command)
            else:
                self.nvim.async_call(self.handle, ctx, res)

    @neovim.function('_wilder_init', sync=True, allow_nested=True)
    def init(self, args):
        if self.has_init:
            return

        self.has_init = True

        opts = args[0]

        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=opts['num_workers'])
        t = threading.Thread(target=self.consumer, daemon=True)
        t.start()

    @neovim.function('_wilder_python_sleep', sync=False)
    def sleep(self, args):
        self.run_in_background(self.sleep_handler, args)

    def sleep_handler(self, t, ctx, x):
        time.sleep(t)
        self.queue.put((ctx, x,))

    @neovim.function('_wilder_python_search', sync=False, allow_nested=True)
    def search(self, args):
        if args[2] == "":
            self.handle(args[1], [])
            return

        line_num = self.nvim.current.window.cursor[0] - 1
        current_buf = self.nvim.current.buffer
        buf = current_buf[line_num:] + current_buf[:line_num]

        event = threading.Event()

        with self.lock:
            while len(self.events) > 0:
                e = self.events.pop(0)
                e.set()

            self.events.append(event)

        self.run_in_background(self.search_handler, [event, buf] + args)

    def search_handler(self, event, buf, opts, ctx, x):
        if event.is_set():
            return

        try:
            module_name = opts['engine'] if 'engine' in opts else 're'
            max_candidates = opts['max_candidates'] if 'max_candidates' in opts else 300

            seen = set()
            candidates = []

            re = importlib.import_module(module_name)
            pattern = re.compile(x)

            for line in buf:
                if event.is_set():
                    return
                for match in pattern.finditer(line):
                    if event.is_set():
                        return
                    candidate = match.group()
                    if not candidate in seen:
                        seen.add(candidate)
                        candidates.append(candidate)
                        if max_candidates > 0 and len(candidates) >= max_candidates:
                            self.queue.put((ctx, candidates,))
                            return
            self.queue.put((ctx, candidates,))
        except Exception as e:
            self.queue.put((ctx, 'python_search: ' + str(e), 'reject',))
        finally:
            with self.lock:
                self.events.remove(event)

    @neovim.function('_wilder_python_uniq', sync=False)
    def uniq(self, args):
        ctx = args[0]
        items = args[1]

        seen = set()

        try:
            res = [x for x in items if not (x in seen or seen.add(x))]
            self.queue.put((ctx, res,))
        except Exception as e:
            self.queue.put((ctx, 'python_uniq: ' + str(e), 'reject',))

    @neovim.function('_wilder_python_sort', sync=False, allow_nested=True)
    def sort(self, args):
        ctx = args[0]
        items = args[1]

        try:
            res = sorted(items)

            self.queue.put((ctx, res,))
        except Exception as e:
            self.queue.put((ctx, 'python_sort: ' + str(e), 'reject',))

    @neovim.function('_wilder_python_get_file_completion', sync=False, allow_nested=True)
    def get_file_completion(self, args):
        event = threading.Event()

        wildignore = self.nvim.options.get('wildignore')

        if args[3] == 'file_in_path':
            path_opt = self.nvim.options.get('path') if args[3] == 'file_in_path' else ''
            directories = path_opt.split(',')
        elif args[3] == 'shellcmd':
            path = os.environ['PATH']
            directories = path.split(':')
        else:
            directories = [args[1]]

        with self.lock:
            while len(self.events) > 0:
                e = self.events.pop(0)
                e.set()

            self.events.append(event)

        self.run_in_background(self.get_file_completion_handler, [event] + args + [directories, wildignore])

    def get_file_completion_handler(self,
                                    event,
                                    ctx,
                                    working_directory,
                                    expand_arg,
                                    expand_type,
                                    has_wildcard,
                                    directories,
                                    wildignore_opt):
        if event.is_set():
            return

        try:
            res = []
            wildignore_list = wildignore_opt.split(',')

            for directory in directories:
                if event.is_set():
                    return
                if not directory:
                    continue

                if has_wildcard:
                    tail = os.path.basename(expand_arg)
                    show_hidden = tail.startswith('.')
                    pattern = ''
                    wildcard = os.path.join(directory, expand_arg)

                    it = glob.iglob(wildcard, recursive=True)
                else:
                    path = os.path.join(directory, expand_arg)
                    (head, tail) = os.path.split(path)
                    show_hidden = tail.startswith('.')
                    pattern = tail + '*'

                    try:
                        it = os.scandir(head)
                    except FileNotFoundError:
                        continue

                if 'path_prefix' in ctx:
                    path_prefix = ctx['path_prefix']
                else:
                    path_prefix = ''

                for entry in it:
                    if event.is_set():
                        return
                    try:
                        if has_wildcard:
                            entry = Path(entry)
                            try:
                                entry = entry.relative_to(directory)
                            except ValueError:
                                pass
                        if entry.name.startswith('.') and not show_hidden:
                            continue
                        if expand_type == 'dir' and not entry.is_dir():
                            continue
                        ignore = False
                        for wildignore in wildignore_list:
                            if fnmatch.fnmatch(entry.name, wildignore):
                                ignore = True
                                break
                        if ignore:
                            continue
                        if not has_wildcard and pattern and not fnmatch.fnmatch(entry.name, pattern):
                            continue
                        if expand_type == 'shellcmd' and (
                                not entry.is_file() or not os.access(os.path.join(directory, entry.name), os.X_OK)):
                            continue
                        name = str(entry) if has_wildcard else entry.name
                        if Path(name) == Path(path_prefix):
                            res.append(os.path.join(path_prefix, './'))
                        elif entry.is_dir():
                            res.append((str(entry) if has_wildcard else entry.name) + os.sep)
                        else:
                            res.append(str(entry) if has_wildcard else entry.name)
                    except OSError:
                        pass
            res = sorted(res)

            head = os.path.dirname(expand_arg)
            if not has_wildcard:
                res = list(map(lambda f: os.path.join(head, f) if head else f, res))

            if expand_arg == '.':
                res.insert(0, '../')
                res.insert(0, './')
            elif expand_arg == '..':
                res.insert(0, '../')

            self.queue.put((ctx, res,))
        except Exception as e:
            self.queue.put((ctx, 'python_get_file_completion: ' + str(e), 'reject',))

    @neovim.function('_wilder_python_filter', sync=False, allow_nested=True)
    def filter(self, args):
        ctx = args[0]
        pattern = args[1]
        candidates = args[2]
        engine = args[3]

        try:
            expand = ctx.get('expand', '')
            has_file_args = expand == 'dir' or expand == 'file' or expand == 'file_in_path'
            re = importlib.import_module(engine)
            pattern = re.compile(pattern)
            res = filter(lambda x: pattern.match(x if not has_file_args else self.get_basename(x)), candidates)
            self.queue.put((ctx, list(res),))
        except Exception as e:
            self.queue.put((ctx, 'python_filter: ' + str(e), 'reject',))

    def get_basename(self, f):
        if f.endswith(os.sep) or f.endswith('/'):
            return os.path.basename(f[:-1])
        return os.path.basename(f)

    @neovim.function('_wilder_python_get_users', sync=False, allow_nested=True)
    def get_users(self, args):
        event = threading.Event()

        with self.lock:
            while len(self.events) > 0:
                e = self.events.pop(0)
                e.set()

            self.events.append(event)

        self.run_in_background(self.get_users_handler, [event] + args)

    def get_users_handler(self, event, ctx, expand_arg, expand_type):
        if event.is_set():
            return

        try:
            res = []

            for user in pwd.getpwall():
                if user.pw_name.startswith(expand_arg):
                    res.append(user.pw_name)

            res = sorted(res)
            self.queue.put((ctx, res,))
        except Exception as e:
            self.queue.put((ctx, 'python_get_users: ' + str(e), 'reject',))
