import time
import multiprocessing
import functools
import importlib
import concurrent.futures
import neovim

@neovim.plugin
class Wildsearch(object):
    def __init__(self, nvim):
        self.nvim = nvim

    def do(self, ctx, x):
        self.nvim.async_call(lambda: self.nvim.call('wildsearch#pipeline#do', ctx, x))

    def echo(self, x):
        self.nvim.session.threadsafe_call(lambda: self.nvim.command('echom "' + x + '"'))

    def run_in_background(self, fn, args):
        self.nvim.loop.run_in_executor(
            None,
            functools.partial(
                fn,
                *args,
            )
        )

    @neovim.function('_wildsearch_init', sync=True)
    def init(self, args):
        self.nvim.command('let g:wildsearch_init = 1')
        self.nvim.session.threadsafe_call(lambda: self.nvim.command('let g:wildsearch_init = 1'))

    @neovim.function('_wildsearch_python_sleep', sync=True)
    def sleep(self, args):
        self.run_in_background(self.sleep_handler, args)
        return None

    def sleep_handler(self, t, ctx, x):
        for _ in range(t):
            time.sleep(1)
        self.do(ctx, x)

    @neovim.function('_wildsearch_python_search_async', sync=True, allow_nested=True)
    def search_async(self, args):
        buf = self.nvim.current.buffer[:].copy()
        self.run_in_background(self.search_handler_async, [buf] + args)
        return None

    @neovim.function('_wildsearch_python_search_sync', sync=True)
    def search_sync(self, args):
        try:
            buf = self.nvim.current.buffer[:].copy()
            candidates, success = self.search_handler(buf, *args)
            if not success:
                return False
            return candidates
        except Exception as e:
            return {'wildsearch_error': str(e)}

    def search_handler_async(self, buf, opts, ctx, x):
        try:
            candidates, success = self.search_handler(buf, opts, ctx, x)
            if not success:
                self.do(ctx, False)
                return
            self.do(ctx, candidates)
        except Exception as e:
            self.do(ctx, {'wildsearch_error': str(e)})

    def search_handler(self, buf, opts, ctx, x):
        module_name = opts['engine'] if 'engine' in opts else 're'
        max_candidates = opts['max_candidates'] if 'max_candidates' in opts else -1

        candidates = []
        re = importlib.import_module(module_name)
        pattern = re.compile(x)

        for line in buf:
            for match in pattern.finditer(line):
                candidates.append(match.group())
                if max_candidates > 0 and len(candidates) >= max_candidates:
                    return candidates, True

        return candidates, True

    @neovim.function('_wildsearch_python_uniq', sync=True)
    def uniq(self, args):
        try:
            return list(set(args[1]))
        except Exception as e:
            return {'wildsearch_error': str(e)}
