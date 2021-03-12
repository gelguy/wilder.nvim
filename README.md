# wilder.nvim
![wilder](https://i.imgur.com/BHA7Rf6.gif)

### A more adventurous wildmenu

`wilder.nvim` adds new features and capabilities to `wildmenu`.
- Automatically provides suggestions as you type
  - `:` cmdline support - autocomplete commands, expressions, filenames, etc.
  - `/` search support - get search suggestions from the current buffer
- High level of customisation
  - build your own custom pipeline to suit your needs
  - customisable look and appearance
- Async query support - use Python 3 for faster and non-blocking queries

# Requirements

- Vim 8.1+ or Neovim 0.3+
- Certain features are only enabled in Neovim

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

When searching using `/`, suggestions will be provided. The default search pipeline uses substring matching.
When in `:` cmdline mode, `wildmenu` suggestions will be automatically provided.

Use `<Tab>` to cycle through the list forwards, and `<S-Tab>` to move backwards.

## Customising the pipeline

By using `wilder#set_option('pipeline', <pipeline>)`, you are able to customise the pipeline to suit your needs.
For example, in Neovim, to use fuzzy matching instead of substring matching:

```vim
" For Neovim only
" For wild#python_search_pipeline():
"   'regex'  : can be set to 'fuzzy_delimiter' for stricter fuzzy matching
"   'engine' : can be set to 're2' for performance, requires pyre2 to be installed
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#cmdline_pipeline({
      \       'fuzzy': 1,
      \       'use_python': 1,
      \     }),
      \     wilder#python_search_pipeline({
      \       'regex': 'fuzzy',
      \       'engine': 're',
      \       'sort': wilder#python_sorter_difflib(),
      \     }),
      \   ),
      \ ])
```

The pipeline is essentially a list of functions (referred to as pipeline components) which are executed in order, passing the result of the previous function to the next one. `wilder#branch()` is a higher-order component which is able to provide control flow given its own lists of components.

See the docs at `:h wilder-pipeline` for a more details. In the meantime, here are some suggestions for pipelines to use:

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

#### Completion during :substitute

```vim
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#substitute_pipeline(),
      \     wilder#cmdline_pipeline(),
      \     wilder#search_pipeline(),
      \   ),
      \ ])
```

Provides suggestions while in the `pattern` part of a substitute command (i.e. when in `:s/{pattern}`). Has to be placed above `wilder#cmdline_pipeline()` in order to work.

Note: For Neovim 0.4+, the candidates are not redrawn correctly if `inccommand` is active.

#### File finder (Experimental) (Neovim only)

```vim
" 'command' : for ripgrep : ['rg', '--files']
"           : for fd      : ['fd', '-tf']
" 'filters' : use ['filter_cpsm'] for performance, needs cpsm to be installed
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#python_file_finder_pipeline({
      \       'command': ['find', '.', '-type', 'f', '-printf', '%P\n'],
      \       'filters': ['filter_fuzzy', 'sort_difflib'],
      \     }),
      \     wilder#cmdline_pipeline(),
      \     wilder#python_search_pipeline(),
      \   ),
      \ ])
```

When getting file completions, fuzzily search and match through all files under the current directory. Has to be placed above `wilder#cmdline_pipeline()`.

To optimise for performane, the `command` and `filters` options can be customised. See `:h wilder#python_file_finder_pipeline()` for more details.

## Customising the renderer

By using `wilder#set_option('renderer', <renderer>)`, you are able to change how `wilder` draws the candidates. By default, `wilder` tries its best to look like the default wildmenu.

### Wildmenu renderer

`wilder#wildmenu_renderer()` draws the candidates above the cmdline. For Neovim 0.4+, a floating window is used. Otherwise the statusline is used.
Due to statusline limitations, the wildmenu only fills up the width of the current window.

```vim
" 'highlighter'    : applies highlighting to the candidates
call wilder#set_option('renderer', wilder#wildmenu_renderer({
      \ 'highlighter': wilder#query_highlighter(),
      \ })
```

### Popupmenu renderer (Experimental) (Neovim only)

For Neovim 0.4+, `wilder#popupmenu_renderer()` can be used.

```vim
" 'highlighter'    : applies highlighting to the candidates
call wilder#set_option('renderer', wilder#popupmenu_renderer({
      \ 'highlighter': wilder#query_highlighter(),
      \ })
```

Use `wilder#renderer_mux()` to choose which renderer to use for different cmdline modes.
This is helpful since the popupmenu will block the current window when searching with `/`.

```vim
call wilder#set_option('renderer', wilder#renderer_mux({
      \ ':': wilder#popupmenu_renderer(),
      \ '/': wilder#wildmenu_renderer(),
      \ })
```

#### Configuration in the screenshot

```vim
" use wilder#lightline_theme() if using Lightline
" 'highlights' : can be overriden, see :h wilder#wildmenu_renderer()
call wilder#set_option('renderer', wilder#wildmenu_renderer(
      \ wilder#airline_theme({
      \   'highlights': {},
      \   'highlighter': wilder#query_highlighter(),
      \   'separator': ' · ',
      \ })))
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
