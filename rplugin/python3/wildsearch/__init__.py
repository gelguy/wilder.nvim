import neovim
import time
import multiprocessing

@neovim.plugin
class Wildsearch(object):
    def __init__(self, vim):
        self.vim = vim

    @neovim.function('_wildsearch_sleep')
    def wildsearch_sleep(self, args):
        time.sleep(args[1])
        self.vim.call('wildsearch#do', args[0], args[2])

        #  args[0]['error_message'] = '123123'
        #  self.vim.call('wildsearch#do', args[0], False)
