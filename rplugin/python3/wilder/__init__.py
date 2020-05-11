import asyncio
import concurrent.futures
import difflib
import fnmatch
import functools
import glob
import importlib
from importlib.util import find_spec
import itertools
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
        self.cached_buffer = {'bufnr': -1, 'undotree_seq_cur': -1, 'buffer': []}
        self.run_id = -1

    def handle(self, ctx, x, command='resolve'):
        self.nvim.call('wilder#' + command, ctx, x)

    def echomsg(self, x):
        self.nvim.session.threadsafe_call(lambda: self.nvim.command('echomsg "' + x + '"'))

    def run_in_background(self, fn, args):
        event = threading.Event()
        ctx = args[0]

        with self.lock:
            if ctx['run_id'] < self.run_id:
                return
            self.run_id = ctx['run_id']

            while len(self.events) > 0:
                e = self.events.pop(0)
                e.set()

            self.events.append(event)

        self.executor.submit(functools.partial( fn, *([event] + args), ))

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

    @neovim.function('_wilder_init', sync=True)
    def init(self, args):
        if self.has_init:
            return

        self.has_init = True

        opts = args[0]

        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=opts['num_workers'])
        t = threading.Thread(target=self.consumer, daemon=True)
        t.start()

    @neovim.function('_wilder_python_sleep', sync=False, allow_nested=True)
    def sleep(self, args):
        self.run_in_background(self.sleep_handler, args)

    def sleep_handler(self, event, ctx, t, x):
        if event.is_set():
            return

        time.sleep(t)
        self.queue.put((ctx, x,))

    @neovim.function('_wilder_python_search', sync=False)
    def search(self, args):
        if args[2] == "":
            self.handle(args[1], [])
            return

        bufnr = self.nvim.current.buffer.number
        undotree_seq_cur = self.nvim.eval('undotree().seq_cur')
        if (bufnr != self.cached_buffer['bufnr'] or
                undotree_seq_cur != self.cached_buffer['undotree_seq_cur']):
            self.cached_buffer = {
                'bufnr': bufnr,
                'undotree_seq_cur': undotree_seq_cur,
                'buffer': list(self.nvim.current.buffer),
                }

        self.run_in_background(self.search_handler, args + [self.cached_buffer['buffer']])

    def search_handler(self, event, ctx, opts, x, buf):
        if event.is_set():
            return

        try:
            module_name = opts['engine'] if 'engine' in opts else 're'
            max_candidates = opts['max_candidates'] if 'max_candidates' in opts else 300

            seen = set()
            candidates = []

            re = importlib.import_module(module_name)
            # re2 does not use re.UNICODE by default
            pattern = re.compile(x, re.UNICODE)

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

    @neovim.function('_wilder_python_uniq', sync=False, allow_nested=True)
    def uniq(self, args):
        self.run_in_background(self.uniq_handler, args)

    def uniq_handler(self, event, ctx, candidates):
        if event.is_set():
            return

        seen = set()

        try:
            res = [x for x in candidates if not (x in seen or seen.add(x))]
            self.queue.put((ctx, res,))
        except Exception as e:
            self.queue.put((ctx, 'python_uniq: ' + str(e), 'reject',))

    @neovim.function('_wilder_python_sort', sync=False, allow_nested=True)
    def sort(self, args):
        self.run_in_background(self.sort_handler, args)

    def sort_handler(self, event, ctx, candidates):
        if event.is_set():
            return

        try:
            res = sorted(candidates)

            self.queue.put((ctx, res,))
        except Exception as e:
            self.queue.put((ctx, 'python_sort: ' + str(e), 'reject',))

    @neovim.function('_wilder_python_get_file_completion', sync=False)
    def get_file_completion(self, args):
        if args[2] == 'file_in_path':
            path_opt = self.nvim.eval('&path')
            directories = path_opt.split(',')
            directories += [self.nvim.eval('expand("%:h")')]
        elif args[2] == 'shellcmd':
            path = os.environ['PATH']
            directories = path.split(':')
        else:
            directories = [self.nvim.eval('getcwd()')]

        wildignore_opt = self.nvim.eval('&wildignore')

        self.run_in_background(self.get_file_completion_handler, args + [wildignore_opt, directories])

    def get_file_completion_handler(self,
                                    event,
                                    ctx,
                                    expand_arg,
                                    expand_type,
                                    has_wildcard,
                                    path_prefix,
                                    wildignore_opt,
                                    directories):
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
                    wildcard = os.path.expandvars(wildcard)

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
                        if has_wildcard and Path(entry) == Path(path_prefix):
                            continue

                        if entry.is_dir():
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

    def get_basename(self, f):
        if f.endswith(os.sep) or f.endswith('/'):
            return os.path.basename(f[:-1])
        return os.path.basename(f)

    @neovim.function('_wilder_python_get_users', sync=False, allow_nested=True)
    def get_users(self, args):
        self.run_in_background(self.get_users_handler, args)

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

    @neovim.function('_wilder_python_filter', sync=False, allow_nested=True)
    def filter(self, args):
        self.run_in_background(self.filter_handler, args)

    def filter_handler(self, event, ctx, pattern, candidates, engine, has_file_args):
        if event.is_set():
            return

        try:
            re = importlib.import_module(engine)
            # re2 does not use re.UNICODE by default
            pattern = re.compile(pattern, re.UNICODE)
            res = filter(lambda x: pattern.search(x if not has_file_args else self.get_basename(x)), candidates)
            self.queue.put((ctx, list(res),))
        except Exception as e:
            self.queue.put((ctx, 'python_filter: ' + str(e), 'reject',))

    @neovim.function('_wilder_python_sort_difflib', sync=False, allow_nested=True)
    def sort_difflib(self, args):
        self.run_in_background(self.sort_difflib_handler, args)

    def sort_difflib_handler(self, event, ctx, candidates, query, quick=True):
        if event.is_set():
            return

        try:
            if quick:
                res = sorted(candidates, key=lambda x: -difflib.SequenceMatcher(
                    None, x, query).quick_ratio())
            else:
                res = sorted(candidates, key=lambda x: -difflib.SequenceMatcher(
                    None, x, query).ratio())
            self.queue.put((ctx, list(res),))
        except Exception as e:
            self.queue.put((ctx, 'python_sort_difflib: ' + str(e), 'reject',))

    @neovim.function('_wilder_python_sort_fuzzywuzzy', sync=False, allow_nested=True)
    def sort_fuzzywuzzy(self, args):
        self.run_in_background(self.sort_fuzzywuzzy_handler, args)

    def sort_fuzzywuzzy_handler(self, event, ctx, candidates, query, partial=True):
        if event.is_set():
            return

        try:
            fuzzy = importlib.import_module('fuzzywuzzy.fuzz')
            if partial:
                res = sorted(candidates, key=lambda x: -fuzzy.partial_ratio(x, query))
            else:
                res = sorted(candidates, key=lambda x: -fuzzy.ratio(x, query))
            self.queue.put((ctx, list(res),))
        except Exception as e:
            self.queue.put((ctx, 'python_sort_fuzzywuzzy: ' + str(e), 'reject',))

    @neovim.function('_wilder_python_common_subsequence_spans', sync=True)
    def common_subsequence_spans(self, args):
        string = args[0]
        query = args[1]
        case_sensitive = args[2]

        if not case_sensitive:
            string = string.upper()
            query = query.upper()

        result = []
        blocks = difflib.SequenceMatcher(None, string, query).get_matching_blocks()
        for block in blocks[: -1]:
            start = block.a
            end = block.a + block.size

            byte_start = len(string[: start].encode('utf-8'))
            byte_len = len(string[start : end].encode('utf-8'))
            result.append([byte_start, byte_len])

        return result

    @neovim.function('_wilder_python_pcre2_capture_spans', sync=True)
    def capture_spans(self, args):
        pattern = args[0]
        string = args[1]
        module_name = args[2]

        re = importlib.import_module(module_name)
        match = re.match(pattern, string)

        if not match or not match.lastindex:
            return  []

        captures = []
        for i in range(1, match.lastindex + 1):
            start = match.start(i)
            end = match.end(i)
            if start == -1 or end == -1 or start == end:
                continue

            byte_start = len(string[: start].encode('utf-8'))
            byte_len = len(string[start : end].encode('utf-8'))
            captures.append([byte_start, byte_len])

        return captures
