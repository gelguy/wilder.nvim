import time
import multiprocessing
import functools
import importlib
import concurrent.futures
import threading
import asyncio
import neovim

@neovim.plugin
class Wildsearch(object):
    def __init__(self, nvim):
        self.nvim = nvim
        self.has_init = False
        self.queue = multiprocessing.Queue()
        self.events = []
        self.lock = threading.Lock()
        self.executor = None

    def do(self, ctx, x, command='do'):
        self.nvim.call('wild#pipeline#' + command, ctx, x)

    def echo(self, x):
        self.nvim.session.threadsafe_call(lambda: self.nvim.command('echom "' + x + '"'))

    def run_in_background(self, fn, args):
        self.executor.submit(
            functools.partial(
                fn,
                *args,
            )
        )

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
                self.nvim.async_call(self.do, ctx, res, command=command)
            else:
                self.nvim.async_call(self.do, ctx, res)

    @neovim.function('_wild_init', sync=True, allow_nested=True)
    def init(self, args):
        if self.has_init:
            return

        self.has_init = True

        opts = args[0]

        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=opts['num_workers'])
        t = threading.Thread(target=self.consumer, daemon=True)
        t.start()

    @neovim.function('_wild_python_sleep', sync=False)
    def sleep(self, args):
        self.run_in_background(self.sleep_handler, args)

    def sleep_handler(self, t, ctx, x):
        time.sleep(t)
        self.queue.put((ctx, x,))

    @neovim.function('_wild_python_search', sync=False, allow_nested=True)
    def search(self, args):
        if args[2] == "":
            self.do(args[1], [])
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

        module_name = opts['engine'] if 'engine' in opts else 're'
        max_candidates = opts['max_candidates'] if 'max_candidates' in opts else 300

        seen = set()
        candidates = []

        try:
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
            self.queue.put((ctx, str(e), 'do_error',))
        finally:
            with self.lock:
                self.events.remove(event)

    @neovim.function('_wild_python_uniq', sync=False)
    def uniq(self, args):
        ctx = args[0]
        items = args[1]

        seen = set()

        try:
            res = [x for x in items if not (x in seen or seen.add(x))]
            self.queue.put((ctx, res,))
        except Exception as e:
            self.queue.put((ctx, str(e), 'do_error',))

    @neovim.function('_wild_python_sort', sync=False, allow_nested=True)
    def sort(self, args):
        ctx = args[0]
        items = args[1]

        try:
            res = sorted(items)

            self.queue.put((ctx, res,))
        except Exception as e:
            self.queue.put((ctx, str(e), 'do_error',))
