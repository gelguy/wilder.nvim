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
- Certain features (e.g. Python 3 and async search) are only enabled in Neovim

# Install

```vim
" with dein
call dein#add('gelguy/wilder.nvim')

" with vim-plug
" UpdateRemotePlugins needed
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
      \     wilder#cmdline_pipeline({
      \       'fuzzy': 1,
      \       'use_python': 1,
      \     }),
      \     wilder#python_search_pipeline({
      \       'regex': 'fuzzy',   " use 'fuzzy_delimiter' for stricter fuzzy matching
      \       'engine': 're',     " use 're2' for performance, requires Python re2 to be installed
      \       'sort': function('wilder#python_sort_difflib'),
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

Note: For Neovim 0.4+, the candidates are not redrawn correctly if `inccommand` is active.

## Customising the renderer

By using `wilder#set_option('renderer', <renderer>)`, you are able to change how `wilder` draws the candidates. By default, `wilder` tries its best to look like the default wildmenu.

`wilder` currently provides 1 renderer `wilder#wildmenu_renderer()` by default. For Neovim 0.4+, the candidates are drawn using a floating window. Otherwise, the candidates are drawn on the statusline. Drawing on the statusline has the limitation that its width is limited to the current window.

```vim
" default settings
call wilder#set_option('renderer', wilder#wildmenu_renderer({
      \ 'highlights': {
      \   'default': 'StatusLine', " default highlight to use
      \   'selected': 'WildMenu',  " highlight for the selected item
      \ },
      \ 'apply_highlights':        " Experimental: applies highlighting to candidates
      \    wilder#query_common_subsequence_spans(),
      \ 'separator': ' ',          " string used to separate candidates
      \ 'ellipsis': '...',         " string appended to truncated candidates which are too long
      \ })
```

The renderer options include the fields `left` and `right`. Use these to add renderer components which help to provide more information on the current state of the candidates. Unlike pipeline components, render components can take the form of strings, functions, dictionaries and lists. See `:h wilder-renderer` for more details.

Note: the more components in the renderer, the more computation is needed to draw it. This may result in noticeable input lag as the wildmenu has to be redrawn on every keystroke.

Here are some examples of the built-in components:

#### Index n/m

```vim
call wilder#set_option('renderer', wilder#wildmenu_renderer({
      \ 'right': [wilder#index()],
      \ })
```

Shows the index of the current candidate out of the total number of candidates - e.g. ` 12/50`.

#### Spinner

```vim
call wilder#set_option('renderer', wilder#wildmenu_renderer({
      \ 'spinner': [wilder#spinner({
      \   'frames': '-\|/',  " characters to show, can also be a list of strings
      \   'done': ' ',       " string to show when there is no work to do or work has finished
      \   'delay': 50,       " delay in ms before showing the spinner
      \   'interval': 100,   " interval in ms for each frame to be shown
      \ )],
      \ })
```

The spinner indicates when `wilder` has async work which has not been completed yet.

#### Configuration in the screenshot

```vim

call wilder#set_option('renderer', wilder#wildmenu_renderer(
      \ wilder#airline_theme({  " use wilder#lightline_theme() for Lightline
      \   'highlights': {},     " default highlights can be overridden, see :h wilder#wildmenu_renderer()
      \   'apply_highlights': wilder#query_common_subsequence_spans(),
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
