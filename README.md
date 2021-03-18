# wilder.nvim
### A more adventurous wildmenu

`wilder.nvim` adds new features and capabilities to `wildmenu`.
- Automatically provides suggestions as you type
  - `:` cmdline support - autocomplete commands, expressions, filenames, etc.
  - `/` search support - get search suggestions from the current buffer
- High level of customisation
  - build your own custom pipeline to suit your needs
  - customisable look and appearance
- Async query support - uses Python 3 remote plugin for faster and non-blocking queries

![wilder](https://i.imgur.com/5kkjB7X.gif)

# Requirements

- Vim 8.1+ or Neovim 0.3+
- Python support only in Neovim
- Floating window support only in Neovim 0.4+

# Install

```vim
" with dein
call dein#add('gelguy/wilder.nvim')

" with vim-plug
" :UpdateRemotePlugins needed
Plug 'gelguy/wilder.nvim'
```

# Usage

## Getting started

Start with the following minimal configuration in your `init.vim` or `.vimrc`:

```vim
call wilder#enable_cmdline_enter()
set wildcharm=<Tab>
cmap <expr> <Tab> wilder#in_context() ? wilder#next() : "\<Tab>"
cmap <expr> <S-Tab> wilder#in_context() ? wilder#previous() : "\<S-Tab>"

" only / and ? is enabled by default
call wilder#set_option('modes', ['/', '?', ':'])
```

When in `:` cmdline mode, `wildmenu` suggestions will be automatically provided.
When searching using `/`, suggestions will be provided. The default uses substring matching.

Use `<Tab>` to cycle through the list forwards, and `<S-Tab>` to move backwards.

## Customising the pipeline

Use `wilder#set_option('pipeline', <pipeline>)` to customise the pipeline.
For example, in Neovim, to use fuzzy matching instead of substring matching:

```vim
" For Neovim only
" For wild#cmdline_pipeline():
"   'fuzzy'      : set fuzzy searching
"   'use_python' : use python for fuzzy searching
" For wild#python_search_pipeline():
"   'pattern'    : can be set to wilder#python_fuzzy_delimiter_pattern() for stricter fuzzy matching
"   'engine'     : can be set to 're2' for performance, requires pyre2 to be installed
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#cmdline_pipeline({
      \       'fuzzy': 1,
      \       'use_python': 1,
      \     }),
      \     wilder#python_search_pipeline({
      \       'pattern': wilder#python_fuzzy_pattern(),
      \       'sorter': wilder#python_difflib_sorter(),
      \       'engine': 're',
      \     }),
      \   ),
      \ ])
```

![Fuzzy](https://i.imgur.com/rFgEVJ2.png)

The pipeline is essentially a list of functions (referred to as pipes) which are executed in order, passing the result of the previous function to the next one.
`wilder#branch()` is a higher-order pipe which is able to provide control flow given its own lists of pipelines.

See the docs at `:h wilder-pipeline` for a more details. In the meantime, here are some pipeline examples:

#### History

```vim
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     [
      \       wilder#check({_, x -> empty(x)}),
      \       wilder#history(),
      \     ],
      \     wilder#cmdline_pipeline(),
      \     wilder#search_pipeline(),
      \   ),
      \ ])
```

When the cmdline is empty, provide suggestions based on the cmdline history (`:h cmdline-history`).

With a Devicons font:

```vim
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     [
      \       wilder#check({_, x -> empty(x)}),
      \       wilder#history(),
      \       wilder#result({
      \         'draw': [{_, x -> ' ' . x}],
      \       }),
      \     ],
      \     wilder#cmdline_pipeline(),
      \     wilder#search_pipeline(),
      \   ),
      \ ])
```

![History](https://i.imgur.com/BuDPosq.png)

#### File finder (Experimental) (Neovim only)

```vim
" 'file_command' : for ripgrep : ['rg', '--files']
"                : for fd      : ['fd', '-tf']
" 'dir_command'  : for fd      : ['fd', '-td']
" 'filters'      : use ['cpsm_filter'] for performance, needs cpsm to be installed
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#python_file_finder_pipeline({
      \       'file_command': ['find', '.', '-type', 'f', '-printf', '%P\n'],
      \       'dir_command': ['find', '.', '-type', 'd', '-printf', '%P\n'],
      \       'filters': ['fuzzy_filter', 'difflib_sorter'],
      \     }),
      \     wilder#cmdline_pipeline(),
      \     wilder#python_search_pipeline(),
      \   ),
      \ ])
```

![File finder](https://i.imgur.com/2gmT1vq.png)

When getting file completions, fuzzily search and match through all files under the current directory.
Has to be placed above `wilder#cmdline_pipeline()`.

To optimise for performane, the `file_command`, `dir_command` and `filters` options can be customised.
See `:h wilder#python_file_finder_pipeline()` for more details.

#### Devicons (Experimental)

`ryanoasis/vim-devicons` is required. Note: the API is experimental and subject to change.

```vim
" Add wilder#result_draw_devicons() to the end of the pipeline
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \      ... pipelines ...
      \   ),
      \   wilder#result_draw_devicons(),
      \ ])
```

![Devicons](https://i.imgur.com/twcyhtv.png)

## Customising the renderer

Use `wilder#set_option('renderer', <renderer>)` to change how `wilder` draws the results.
By default, `wilder` tries its best to look like the default wildmenu.

### Wildmenu renderer

`wilder#wildmenu_renderer()` draws the candidates above the cmdline.
For Neovim 0.4+, a floating window is used. Otherwise the statusline is used.
Due to statusline limitations, the wildmenu only fills up the width of the current window.

```vim
" 'highlighter' : applies highlighting to the candidates
call wilder#set_option('renderer', wilder#wildmenu_renderer({
      \ 'highlighter': wilder#basic_highlighter(),
      \ }))
```

![Default](https://i.imgur.com/vIgIt4v.png)

An alternative theme which shows a spinner and the current number of items:

```vim
call wilder#set_option('renderer', wilder#wildmenu_renderer({
      \ 'highlighter': wilder#basic_highlighter(),
      \ 'separator': ' · ',
      \ 'left': [' ', wilder#wildmenu_spinner(), ' '],
      \ 'right': [' ', wilder#wildmenu_index()],
      \ }))
```

![Minimal](https://i.imgur.com/AifaC11.png)

For Airline and Lightline users, `wilder#airline_theme()` and `wilder#lightline_theme()` can be used.

```vim
" use wilder#lightline_theme() if using Lightline
" 'highlights' : can be overriden, see :h wilder#wildmenu_renderer()
call wilder#set_option('renderer', wilder#wildmenu_renderer(
      \ wilder#airline_theme({
      \   'highlights': {},
      \   'highlighter': wilder#basic_highlighter(),
      \   'separator': ' · ',
      \ })))
```

![Airline](https://i.imgur.com/1HemK0l.png)

### Popupmenu renderer (Experimental) (Neovim only)

For Neovim 0.4+, `wilder#popupmenu_renderer()` can be used to draw the results on a popupmenu, similar to `wildoptions+=pum`.

```vim
" 'highlighter' : applies highlighting to the candidates
call wilder#set_option('renderer', wilder#popupmenu_renderer({
      \ 'highlighter': wilder#basic_highlighter(),
      \ }))
```

![Popupmenu](https://i.imgur.com/YcVk7le.png)

Use `wilder#renderer_mux()` to choose which renderer to use for different cmdline modes.
This is helpful since the popupmenu might overlap the current window when searching with `/`.

```vim
call wilder#set_option('renderer', wilder#renderer_mux({
      \ ':': wilder#popupmenu_renderer({
      \   ... settings ...
      \ }),
      \ '/': wilder#wildmenu_renderer({
      \   ... settings ...
      \ }),
      \ }))
```

# Tips

#### Disabling in the case of errors

Use `q:` to open the `cmdline-window` and enter the following command

```
call wilder#disable()
```

Alternatively, define a mapping in your `init.vim` or `.vimrc`

```
nnoremap <expr> <Leader>w wilder#toggle()
```

# Acknowledgements

Many thanks to the following codebases for providing ideas and reference:
> [denite.nvim](https://github.com/Shougo/denite.nvim)

> [fzf.vim](https://github.com/junegunn/fzf.vim)

> [vim-airline](https://github.com/vim-airline/vim-airline)

> [lightline.vim](https://github.com/itchyny/lightline.vim)

> [cpsm](https://github.com/nixprime/cpsm)

> [fruzzy](https://github.com/raghur/fruzzy)

> [LeaderF](https://github.com/Yggdroot/LeaderF)

> [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

> [vim-devicons](https://github.com/ryanoasis/vim-devicons)

> [scrollbar.nvim](https://github.com/Xuyuanp/scrollbar.nvim)

> and many more!
