# wilder.nvim
![search](https://i.imgur.com/kjgwCRz.png)

### A more adventurous wildmenu

`wilder.nvim` adds new features and capabilities to `wildmenu`.
- Automatically provides suggestions as you type
  - `/` search support - get search suggestions as from the current buffer
  - `:` cmdline support - autocomplete commands, expressions, filenames, etc.
- High level of customisation
  - build your own custom pipeline to suit your needs
  - customisable look and appearance
- Async query support - use Python 3 for faster and non-blocking queries

# Requirements

- Vim 8.1+ or Neovim 0.3+
- Certain features (e.g. Python 3 and async search) are only enabled in Neovim

# Install

```vim
" with dein
call dein#add('gelguy/wilder.nvim')

" with vim-plug
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

When searching using `/`, you will find that suggestions are provided on the statusline. The default search pipeline uses substring matching.
When in `:` cmdline mode, `wildmenu` suggestions will be automatically provided.

Use `<Tab>` to cycle through the list forwards, and `<S-Tab>` to move backwards.

## Customising the pipeline

By using `wilder#set_option('pipeline', <pipeline>)`, you are able to customise the pipeline to suit your needs.
For example, in Neovim, to use fuzzy matching instead of substring matching:

```vim
" For Neovim
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#cmdline_pipeline({'fuzzy': 1}),
      \     wilder#python_search_pipeline({
      \       'mode': 'fuzzy', " use 'fuzzy_delimiter' for stricter fuzzy matching
      \       'engine': 're',  " use 're2' for performance, requires Python re2 to be installed
      \       'fuzzy_sort': 1, " Python fuzzywuzzy module required
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
      \     wilder#vim_search_pipeline(),  " or wilder#python_search_pipeline() for Neovim
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
      \     wilder#vim_search_pipeline(),  " or wilder#python_search_pipeline() for Neovim
      \   ),
      \ ])
```

Provides suggestions while in the `pattern` part of a substitute command (i.e. when in `:s/{pattern}`). Has to be placed above `wilder#cmdline_pipeline()` in order to work.

Note: For Neovim, read `:h wilder#substitute_pipeline()` for its interaction with `inccommand`.

## Customising the renderer

By using `wilder#set_option('renderer', <renderer>)`, you are able to change how `wilder` is drawn on the statusline and which renderer components you wish to show. By default, `wilder` tries its best to look like (Neo)Vim's default wildmenu.

`wilder` provides 2 built-in renderers - `wilder#statusline_renderer()` and `wilder#float_renderer()`. The float renderer is only available in Neovim 0.4+ with `api-floatwin`. `exists('*nvim_open_win')` can be used to check that floating windows are supported. The statusline renderer has a limitation that it can only draw in the statusline of the current window. To replace the wildmenu, the float renderer has to be used.

Both the statusline renderer and float renderer use the same options and components.

```vim
" default settings
call wilder#set_option('renderer', wilder#statusline_renderer({
      \ 'highlights': {
      \   'default': 'StatusLine', " default highlight to use
      \   'selected': 'WildMenu',  " highlight for the selected item
      \ },
      \ 'separator': '  ',         " string used to separate candidates
      \ 'ellipsis': '...',         " string appended to truncated candidates which are too long
      \ })
```

The renderer options include the fields `left` and `right`. Use these to add renderer components which help to provide more information on the current state of the candidates. Unlike pipeline components, render components can take the form of strings, functions, dictionaries and lists. See `:h wilder-renderer` for more details. Here are some examples of the built-in components:

#### Index n/m

```vim
call wilder#set_option('renderer', wilder#statusline_renderer({
      \ 'right': [wilder#index()],
      \ })
```

Shows the index of the current candidate out of the total number of candidates - e.g. ` 12/50`.

#### Spinner

```vim
call wilder#set_option('renderer', wilder#statusline_renderer({
      \ 'spinner': [wilder#spinner({
      \   'frames': '-\|/',  " characters to show, can also be a list of strings
      \   'done': ' ',  " string to show when there is no work to do or work has finished
      \   'delay': 50,  " delay in ms before showing the spinner
      \   'interval': 100,  " interval in ms for each frame to be shown
      \ )],
      \ })
```

The spinner indicates when `wilder` has async work which has not been completed yet.

#### Configuration in the screenshot

```vim
" for vim-airline
let s:hl = 'airline_c'
let s:mode_hl = 'airline_a'
let s:index_hl ='airline_z'

" for lightline.vim
let s:hl = 'LightlineMiddle_active'
let s:mode_hl = 'LightlineLeft_active_0'
let s:index_hl = 'LightlineRight_active_0'

call wilder#set_option('renderer', wilder#float_renderer({
      \ 'highlights': {
      \   'default': s:hl,
      \ },
      \ 'apply_highlights': wilder#query_common_subsequence_spans(),
      \ 'separator': ' · ',
      \ 'left': [{'value': [
      \    wilder#condition(
      \      {-> getcmdtype() ==# ':'},
      \      ' COMMAND ',
      \      ' SEARCH ',
      \    ),
      \    wilder#condition(
      \      {ctx, x -> has_key(ctx, 'error')},
      \      '!',
      \      wilder#spinner({
      \        'frames': '-\|/',
      \        'done': '·',
      \      }),
      \    ), ' ',
      \ ], 'hl': s:mode_hl,},
      \ wilder#separator('', s:mode_hl, s:hl, 'left'), ' ',
      \ ],
      \ 'right': [
      \    ' ', wilder#separator('', s:index_hl, s:hl, 'right'),
      \    wilder#index({'hl': s:index_hl}),
      \ ],
      \ }))
```

Note: the more components in the renderer, the more computation is needed to draw it. This may result in noticeable input lag as the wildmenu has to be redrawn on every keystroke.

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
