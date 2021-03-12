import asyncio
import concurrent.futures
import difflib
import fnmatch
import functools
import glob
import heapq
import importlib
from importlib.util import find_spec
import io
import itertools
import multiprocessing
import os
from pathlib import Path
import pwd
import re
import shutil
import stat
import subprocess
import sys
from tempfile import TemporaryFile
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
        self.events_lock = threading.Lock()
        self.executor = None
        self.cached_buffer = {'bufnr': -1, 'undotree_seq_cur': -1, 'buffer': []}
        self.run_id = -1
        self.find_files_lock = threading.Lock()
        self.find_files_session_id = -1
        self.path_files_dict = dict()
        self.added_sys_path = set()

    def handle(self, ctx, x, command='resolve'):
        self.nvim.call('wilder#' + command, ctx, x)

    def echomsg(self, x):
        self.nvim.session.threadsafe_call(lambda: self.nvim.command('echomsg "' + x + '"'))

    def run_in_background(self, fn, args):
        event = threading.Event()
        ctx = args[0]

        old_events = []
        with self.events_lock:
            run_id = ctx['run_id']
            if run_id < self.run_id:
                return

            if run_id > self.run_id:
                self.run_id = run_id
                old_events = self.events
                self.events = []

            self.events.append(event)

        for ev in old_events:
            ev.set()

        return self.executor.submit(functools.partial( fn, *([event] + args), ))

    def consumer(self):
        while True:
            args = self.queue.get()
            ctx = args[0]
            res = args[1]

            if ctx['run_id'] < self.run_id:
                continue

            if len(args) > 2:
                command = args[2]
                self.nvim.async_call(self.handle, ctx, res, command=command)
            else:
                self.nvim.async_call(self.handle, ctx, res)

    @neovim.function('_wilder_init', sync=True)
    def _init(self, args):
        if self.has_init:
            return

        self.has_init = True

        opts = args[0]

        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=opts['num_workers'])
        t = threading.Thread(target=self.consumer, daemon=True)
        t.start()

    def add_sys_path(self, path):
        path = os.path.expanduser(path)

        if not path in self.added_sys_path:
            self.added_sys_path.add(path)
            sys.path.insert(0, path)

    @neovim.function('_wilder_python_file_finder', sync=False)
    def _file_finder(self, args):
        self.run_in_background(self.file_finder_handler, args)

    def file_finder_handler(self, event, ctx, opts, cwd, path, query, find_dir):
        try:
            if not path:
                path = cwd

            path = Path(os.path.expanduser(path)).resolve()
            path_str = str(path)

            if find_dir:
                command = opts['dir_command'] if 'dir_command' in opts else \
                        ['find', '.', '-type', 'd', '-printf', '%P\\n']
            else:
                command = opts['file_command'] if 'file_command' in opts else \
                        ['find', '.', '-type', 'f', '-printf', '%P\\n']

            key = str(path) + ':' + str(command)

            timeout_ms = opts['timeout'] if 'timeout' in opts else 5000
            filters = opts['filters'] if 'filters' in opts else \
                    [{'name': 'filter_fuzzy', 'opts': {}}, {'name': 'sort_difflib', 'opts': {}}]

            result = None
            with self.find_files_lock:
                if ctx['session_id'] > self.find_files_session_id:
                    self.find_files_session_id = ctx['session_id']

                    for result in self.path_files_dict.values():
                        result['kill'].set()

                    self.path_files_dict = dict()

                if key in self.path_files_dict:
                    result = self.path_files_dict[key]
                else:
                    kill_event = threading.Event()
                    done_event = threading.Event()
                    result = {'kill': kill_event, 'done': done_event}
                    self.path_files_dict[key] = result
                    self.executor.submit(functools.partial( self.find_files_subprocess, *([command, path, timeout_ms, result]), ))

            while True:
                if result['done'].is_set():
                    break
                if event.wait(timeout=0.01):
                    return

            if 'timeout' in result:
                self.queue.put((ctx, False,))
                return

            if 'error' in result:
                self.queue.put((ctx, 'find_files: ' + result['error'], 'reject',))
                return

            candidates = result['files']

            if not candidates:
                return self.queue.put((ctx, [],))

            if query:
                for filter in filters:
                    filter_name = filter['name']
                    filter_opts = filter['opts']

                    if filter_name == 'filter_cpsm':
                        filter_opts['ispath'] = True
                        candidates = self.filter_cpsm(event, filter_opts, candidates, query)

                    elif filter_name == 'filter_fruzzy':
                        candidates = self.filter_fruzzy(event, filter_opts, candidates, query)

                    elif filter_name == 'filter_fuzzy':
                        case_sensitive = filter_opts['case_sensitive'] if 'case_sensitive' in filter_opts else 2
                        pattern = self.make_fuzzy_pattern(query, case_sensitive)
                        candidates = self.filter_fuzzy(event, filter_opts, candidates, pattern)

                    elif filter_name == 'sort_difflib':
                        candidates = self.sort_difflib(event, filter_opts, candidates, query)

                    elif filter_name == 'sort_fuzzywuzzy':
                        candidates = self.sort_fuzzywuzzy(event, filter_opts, candidates, query)

                    else:
                        raise Exception('Unsupported filter: ' + filter_name)

                    if candidates is None or event.is_set():
                        return
                    candidates = list(candidates)

            if event.is_set():
                return

            relpath = os.path.relpath(path, cwd)
            if relpath != '.':
                candidates = [os.path.join(relpath, c) for c in candidates]

            if find_dir:
                candidates = [c + os.sep if c and c[-1] != os.sep else c  for c in candidates]

            self.queue.put((ctx, candidates,))
        except Exception as e:
            self.queue.put((ctx, 'python_file_finder: ' + str(e), 'reject'))

    def find_files_subprocess(self, command, path, timeout_ms, result):
        try:
            with TemporaryFile() as output:
                with subprocess.Popen(
                        command, bufsize=0, stdin=subprocess.DEVNULL,
                        stdout=output, stderr=subprocess.DEVNULL, cwd=path) as p:
                    start_time = time.time()
                    while p.poll() is None:
                        if time.time() - start_time >= timeout_ms / 1000:
                            result['timeout'] = 'timeout after %dms' % (timeout_ms)
                            p.kill()
                            break
                        if result['kill'].wait(timeout=0.01):
                            p.kill()
                            break

                    if p.returncode is not 0:
                        # rg sets error code 2 for partial matches, which we are fine with
                        if command[0] is not 'rg' and p.returncode is not 2:
                            result['error'] = 'non-zero return code %d ' % (p.returncode)
                            return

                    output.seek(0)
                    buff = output.read()
                    result['files'] = [line.decode('utf-8') for line in buff.splitlines()]
        except Exception as e:
            result['error'] = str(e)
        finally:
            result['done'].set()

    @neovim.function('_wilder_python_sleep', sync=False)
    def _sleep(self, args):
        self.run_in_background(self.sleep_handler, args)

    def sleep_handler(self, event, ctx, t, x):
        if event.is_set():
            return

        time.sleep(t)
        self.queue.put((ctx, x,))

    @neovim.function('_wilder_python_search', sync=False)
    def _search(self, args):
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

    def search_handler(self, event, ctx, *args):
        try:
            candidates = list(self.search(event, *args))

            if event.is_set():
                return

            self.queue.put((ctx, candidates,))
        except Exception as e:
            self.queue.put((ctx, 'python_search: ' + str(e), 'reject',))

    def search(self, event, opts, x, buf):
        module_name = opts['engine'] if 'engine' in opts else 're'
        max_candidates = opts['max_candidates'] if 'max_candidates' in opts else 300

        re = importlib.import_module(module_name)
        # re2 does not use re.UNICODE by default
        pattern = re.compile(x, re.UNICODE)

        seen = set()
        checker = EventChecker(event)
        for line in buf:
            for match in pattern.finditer(line):
                if checker.check():
                    return

                candidate = match.group()
                if not candidate in seen:
                    seen.add(candidate)
                    yield candidate

                    if max_candidates > 0 and len(seen) >= max_candidates:
                        return

    @neovim.function('_wilder_python_uniq', sync=False)
    def _uniq(self, args):
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

    @neovim.function('_wilder_python_sort', sync=False)
    def _sort(self, args):
        self.run_in_background(self.sort_handler, args)

    def sort_handler(self, event, ctx, candidates):
        if event.is_set():
            return

        try:
            res = sorted(candidates)

            self.queue.put((ctx, res,))
        except Exception as e:
            self.queue.put((ctx, 'python_sort: ' + str(e), 'reject',))

    # sync=True as it needs to query nvim for some data
    @neovim.function('_wilder_python_get_file_completion', sync=True)
    def _get_file_completion(self, args):
        expand_arg = args[1]
        expand_type = args[2]

        cwd = self.nvim.eval('getcwd()')
        wildignore_opt = self.nvim.eval('&wildignore')

        add_dot = False

        if expand_type == 'file_in_path':
            directories = []
            if expand_arg:
                if expand_arg[0:2] == './':
                    directories = [cwd]
                else:
                    relpath = os.path.relpath(expand_arg, cwd)
                    if relpath[0:2] == '..':
                        add_dot = True
                        directories = [cwd]

            if not directories:
                path_opt = self.nvim.eval('&path')
                directories = path_opt.split(',')
                directories += [self.nvim.eval('expand("%:h")')]
        elif expand_type == 'shellcmd':
            directories = []
            if expand_arg:
                if expand_arg[0:2] == './':
                    directories = [cwd]
                else:
                    relpath = os.path.relpath(expand_arg, cwd)
                    if relpath[0:2] == '..':
                        add_dot = True
                        directories = [cwd]

            if not directories:
                path = os.environ['PATH']
                directories = path.split(':')
                directories += [cwd]
        else:
            directories = [cwd]

        self.run_in_background(self.get_file_completion_handler, args + [wildignore_opt, directories, add_dot])

    def get_file_completion_handler(self,
                                    event,
                                    ctx,
                                    expand_arg,
                                    expand_type,
                                    has_wildcard,
                                    path_prefix,
                                    wildignore_opt,
                                    directories,
                                    add_dot):
        if event.is_set():
            return

        try:
            res = set()
            wildignore_list = wildignore_opt.split(',')

            checker = EventChecker(event)
            for directory in directories:
                if checker.check():
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
                    if add_dot:
                        path = os.path.join('.', directory, expand_arg)
                    else:
                        path = os.path.join(directory, expand_arg)
                    head, tail = os.path.split(path)
                    show_hidden = tail.startswith('.')
                    pattern = tail + '*'

                    try:
                        it = os.scandir(head)
                    except FileNotFoundError:
                        continue
                    except NotADirectoryError:
                        continue

                for entry in it:
                    if checker.check():
                        return
                    try:
                        if has_wildcard:
                            entry = Path(entry)
                            try:
                                entry = entry.relative_to(directory)
                                old_entry = Path(entry)
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
                        if expand_type == 'shellcmd' and entry.is_file():
                            if has_wildcard and not entry.stat().st_mode & stat.S_IXUSR:
                                continue
                            elif not has_wildcard and not os.access(entry, os.X_OK):
                                continue
                        if has_wildcard and Path(entry) == Path(path_prefix):
                            continue

                        if entry.is_dir():
                            res.add((str(entry) if has_wildcard else entry.name) + os.sep)
                        else:
                            res.add(str(entry) if has_wildcard else entry.name)
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

    # Returns True if p2 is a descendant of p1
    def is_descendant_path(self, p1, p2):
        return os.path.relpath(p2, p1)[0:2] != '..'

    def get_basename(self, f):
        if f.endswith(os.sep) or f.endswith('/'):
            return os.path.basename(f[:-1])
        return os.path.basename(f)

    @neovim.function('_wilder_python_get_users', sync=False)
    def _get_users(self, args):
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

    @neovim.function('_wilder_python_filter_fuzzy', sync=False)
    def _filter_fuzzy(self, args):
        self.run_in_background(self.filter_fuzzy_handler, args)

    def filter_fuzzy_handler(self, event, ctx, *args):
        try:
            candidates = list(self.filter_fuzzy(event, *args))

            if event.is_set():
                return

            self.queue.put((ctx, candidates,))
        except Exception as e:
            self.queue.put((ctx, 'python_filter_fuzzy: ' + str(e), 'reject',))

    # case_sensitive: 0 - case insensitive
    #                 1 - case sensitive
    #                 2 - smartcase - x matches x|X, X matches X
    def make_fuzzy_pattern(self, query, case_sensitive=2):
        chars = list(query)
        pattern = '(?i)' if not case_sensitive else ''

        first = True
        for char in chars:
            if not first:
                pattern += '.*?'
            first = False

            if char == '\\':
                pattern += '\\\\'
            elif (char == '.' or
                    char == '^' or
                    char == '$' or
                    char == '*' or
                    char == '+' or
                    char == '?' or
                    char == '|' or
                    char == '(' or
                    char == ')' or
                    char == '{' or
                    char == '}' or
                    char == '[' or
                    char == ']'):
                pattern += '\\' + char + ''
            else:
                if case_sensitive == 2:
                    if char.isupper():
                        pattern += char
                    else:
                        pattern += '(' + char + '|' + char.upper() + ')'
                else:
                    pattern += char

        return pattern

    def filter_fuzzy(self, event, opts, candidates, pattern):
        engine = opts['engine'] if 'engine' in opts else 're'
        re = importlib.import_module(engine)
        # re2 does not use re.UNICODE by default
        pattern = re.compile(pattern, re.UNICODE)

        checker = EventChecker(event)
        for candidate in candidates:
            if checker.check():
                return

            if pattern.search(candidate):
                yield candidate

    @neovim.function('_wilder_python_filter_fruzzy', sync=False)
    def _filter_fruzzy(self, args):
        self.run_in_background(self.filter_fruzzy_handler, args)

    def filter_fruzzy_handler(self, event, ctx, *args):
        try:
            candidates = list(self.filter_fruzzy(event, *args))

            if event.is_set():
                return

            self.queue.put((ctx, candidates,))
        except Exception as e:
            self.queue.put((ctx, 'python_filter_fruzzy: ' + str(e), 'reject',))

    def filter_fruzzy(self, *args):
        opts = args[1]

        if 'fruzzy_path' in opts:
            self.add_sys_path(opts['fruzzy_path'])

        use_native = opts['use_native'] if 'use_native' in opts else False
        if use_native:
            return self.filter_fruzzy_native(*args)

        return self.filter_fruzzy_py(*args)

    def filter_fruzzy_native(self, event, opts, candidates, query):
        fruzzy_mod = importlib.import_module('fruzzy_mod')
        limit = opts['limit'] if 'limit' in opts else 1000

        indexes = fruzzy_mod.scoreMatchesStr(query, candidates, '', limit)

        sorted_matches = []
        for index, score in indexes:
            sorted_matches.append(candidates[index])

        return sorted_matches

    def filter_fruzzy_py(self, event, opts, candidates, query):
        fruzzy = importlib.import_module('fruzzy')
        limit = opts['limit'] if 'limit' in opts else 1000

        matches = fruzzy.fuzzyMatches(query, candidates, '', limit)

        checker = EventChecker(event)
        arr = []
        for match in matches:
            if checker.check():
                return
            arr.append(match)

        sorted_matches = heapq.nlargest(limit, arr, key=lambda i: i[5])

        return [match[0] for match in sorted_matches]

    @neovim.function('_wilder_python_filter_cpsm', sync=False)
    def _filter_cpsm(self, args):
        self.run_in_background(self.filter_cpsm_handler, args)

    def filter_cpsm_handler(self, event, ctx, *args):
        try:
            candidates = list(self.filter_cpsm(event, *args))

            if event.is_set():
                return

            self.queue.put((ctx, candidates,))
        except Exception as e:
            self.queue.put((ctx, 'python_filter_cpsm: ' + str(e), 'reject',))

    def filter_cpsm(self, event, opts, candidates, query):
        if 'cpsm_path' in opts:
            self.add_sys_path(opts['cpsm_path'])

        ispath = opts['ispath'] if 'ispath' in opts else False

        cpsm = importlib.import_module('cpsm_py')
        return cpsm.ctrlp_match(candidates, query, ispath=ispath)[0]

    @neovim.function('_wilder_python_sort_difflib', sync=False)
    def _sort_difflib(self, args):
        self.run_in_background(self.sort_difflib_handler, args)

    def sort_difflib_handler(self, event, ctx, *args):
        if event.is_set():
            return

        try:
            candidates = list(self.sort_difflib(event, *args))

            if event.is_set():
                return

            self.queue.put((ctx, candidates,))
        except Exception as e:
            self.queue.put((ctx, 'python_sort_difflib: ' + str(e), 'reject',))

    def sort_difflib(self, event, opts, candidates, query):
        quick = opts['quick'] if 'quick' in opts else True
        case_sensitive = opts['case_sensitive'] if 'case_sensitive' in opts else True

        xs = [None] * len(candidates)
        checker = EventChecker(event)
        for index, candidate in enumerate(candidates):
            if checker.check():
                return

            if case_sensitive:
                matcher = difflib.SequenceMatcher(None, candidate, query)
            else:
                matcher = difflib.SequenceMatcher(None, candidate.lower(), query.lower())
            score = -matcher.quick_ratio() if quick else -matcher.ratio()
            xs[index] = (candidate, score,)

        return [x[0] for x in sorted(xs, key=lambda x: x[1])]

    @neovim.function('_wilder_python_sort_fuzzywuzzy', sync=False)
    def _sort_fuzzywuzzy(self, args):
        self.run_in_background(self.sort_fuzzywuzzy_handler, args)

    def sort_fuzzywuzzy_handler(self, event, ctx, *args):
        try:
            candidates = list(self.sort_fuzzywuzzy(event, *args))

            if event.is_set():
                return

            self.queue.put((ctx, candidates,))
        except Exception as e:
            self.queue.put((ctx, 'python_sort_fuzzywuzzy: ' + str(e), 'reject',))

    def sort_fuzzywuzzy(self, event, opts, candidates, query):
        fuzzy = importlib.import_module('fuzzywuzzy.fuzz')
        partial = opts['partial'] if 'partial' in opts else True
        ratio = fuzzy.partial_ratio if partial else fuzzy.ratio

        xs = [None] * len(candidates)
        checker = EventChecker(event)
        for index, candidate in enumerate(candidates):
            if checker.check():
                return []

            xs[index] = (candidate, -ratio(candidate, query),)

        return [x[0] for x in sorted(xs, key=lambda x: x[1])]

    @neovim.function('_wilder_python_highlight_query', sync=True)
    def _highlight_query(self, args):
        string = args[0]
        query = args[1]
        case_sensitive = args[2]

        if not case_sensitive:
            string = string.upper()
            query = query.upper()

        spans = []
        span = [-1, 0]

        byte_pos = 0
        i = 0
        j = 0
        while i < len(string) and j < len(query):
            match = string[i] == query[j]

            if match:
                j += 1

                if span[0] == -1:
                    span[0] = byte_pos
                span[1] += len(string[i].encode('utf-8'))

            if not match and span[0] != -1:
                spans.append(span)
                span = [-1, 0]

            byte_pos += len(string[i].encode('utf-8'))
            i += 1

        if span[0] != -1:
            spans.append(span)

        return spans

    @neovim.function('_wilder_python_highlight_pcre2', sync=True)
    def _highlight_pcre2(self, args):
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

    @neovim.function('_wilder_python_highlight_cpsm', sync=True)
    def _highlight_cpsm(self, args):

        opts = args[0]
        x = args[1]
        query = args[2]

        if 'cpsm_path' in opts:
            self.add_sys_path(opts['cpsm_path'])

        ispath = opts['ispath'] if 'ispath' in opts else False
        highlight_mode = opts['highlight_mode'] if 'highlight_mode' in opts else 'basic'

        cpsm = importlib.import_module('cpsm_py')
        match = cpsm.ctrlp_match([x], query, ispath=ispath, highlight_mode=highlight_mode)

        if not match[0]:
            return 0

        vim_highlights = match[1]

        spans = []
        for vim_highlight in vim_highlights:
            match = re.search('\\\\zs(.*)\\\\ze', vim_highlight)
            if match:
                start, end = match.span()
                spans.append((start - 6, end - start - 6))

        return spans

class EventChecker:
    def __init__(self, event, interval_s=0.1):
        self.event = event
        self.interval_s = interval_s
        self.last_check = time.time()

    def check(self):
        now = time.time()
        if now - self.last_check < self.interval_s:
            return False

        self.last_check = now
        return self.event.is_set()
