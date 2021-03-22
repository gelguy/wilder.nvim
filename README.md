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

" only / and ? are enabled by default
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
"   'sorter'     : omit to get results in the order they appear in the buffer
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

The pipeline is a list of functions (referred to as pipes) which are executed
in order, passing the result of the previous function to the next one.
`wilder#branch()` is a higher-order pipe which is able to provide control flow given its own lists of pipelines.

See the docs at `:h wilder-pipeline` for a more details. 

Here are some more example pipelines:

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

When getting file completions, fuzzily search and match through all files under the project directory.
Has to be placed above `wilder#cmdline_pipeline()`.

To optimise for performane, the `file_command`, `dir_command` and `filters` options can be customised.
See `:h wilder#python_file_finder_pipeline()` for more details.

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

##### Devicons for popupmenu

Uses `ryanoasis/vim-devicons` by default. To use other plugins, the `get_icon` option can be changed.
See `:h wilder#popupmenu_devicons` for more details.

```vim
call wilder#set_option('renderer', wilder#popupmenu_renderer({
      \ 'highlighter': wilder#basic_highlighter(),
      \ 'left': [
      \   wilder#popupmenu_devicons(),
      \ ],
      \ }))
```

![Devicons](https://i.imgur.com/twcyhtv.png)

### Fuzzy highlighting

The `highlighter` option for both `wilder#wildmenu_renderer()` and `wilder#popupmenu_renderer()`
can be changed for better fuzzy highlighting.

```vim
" Neovim only
" For lua_pcre2_highlighter : requires `luarocks install pcre2`
" For lua_fzy_highlighter   : requires fzy-lua-native vim plugin found
"                             at https://github.com/romgrk/fzy-lua-native
call wilder#set_option('renderer', wilder#popupmenu_renderer({
      \ 'highlighter': [
      \   wilder#lua_pcre2_highlighter(),
      \   wilder#lua_fzy_highlighter(),
      \ ],
      \ }))
```

Other available highlighters are `wilder#python_pcre2_highlighter()` and
`wilder#python_cpsm_highlighter()` which needs `cpsm` to be installed.

# Tips

### Input latency

Input latency when typing in the cmdline is due to `wilder` rendering synchronously.
Rendering time increases for each `wilder#wildmenu_renderer()` item, `wilder#popupmenu_renderer()` column,
or by having a slow `highlighter`.

The fastest configuration for `wilder` is to use the non-fuzzy Python pipelines
and the default renderers.

```vim
" Neovim only
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#cmdline_pipeline({'use_python': 1}),
      \     wilder#python_search_pipeline(),
      \   ),
      \ ])

" The wildmenu renderer is faster than the popupmenu renderer.
" By default no highlighting is applied.

" call wilder#set_option('renderer', wilder#popupmenu_renderer())
call wilder#set_option('renderer', wilder#wildmenu_renderer())
```

If this configuration is still not fast enough, the available options are to
implement a faster renderer e.g. using Lua or to improve the current rendering
code.

If highlighting is important, use the Lua highlighters for best performance.

### Faster Startup time

Define the pipeline and renderer in an `autocmd` so the initialisation is deferred to the first `CmdlineEnter`.

```vim
" Other options should be set outside
call wilder#set_option('modes', ...)

" ++once supported in Nvim 0.4+ and Vim 8.1+
autocmd CmdlineEnter * ++once s:wilder_init()

function! s:wilder_init() abort
  call wilder#set_option('pipeline', ...)
  call wilder#set_option('renderer', ...)
endfunction
```

### Disabling in the case of errors

Use `q:` to open the `cmdline-window` and enter the following command

```vim
call wilder#disable()
```

Alternatively, define a mapping in your `init.vim` or `.vimrc`

```vim
nnoremap <Leader>w :call wilder#toggle()<CR>
```

# Acknowledgements

Many thanks to the following codebases for providing ideas and reference:
> [Shougo/denite.nvim](https://github.com/Shougo/denite.nvim)

> [junegunn/fzf.vim](https://github.com/junegunn/fzf.vim)

> [vim-airline/vim-airline](https://github.com/vim-airline/vim-airline)

> [itchyny/lightline.vim](https://github.com/itchyny/lightline.vim)

> [nixprime/cpsm](https://github.com/nixprime/cpsm)

> [raghur/fruzzy](https://github.com/raghur/fruzzy)

> [Yggdroot/LeaderF](https://github.com/Yggdroot/LeaderF)

> [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

> [ryanoasis/vim-devicons](https://github.com/ryanoasis/vim-devicons)

> [Xuyuanp/scrollbar.nvim](https://github.com/Xuyuanp/scrollbar.nvim)

> and many more!
