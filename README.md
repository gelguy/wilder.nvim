# wilder.nvim

![search](https://i.imgur.com/kjgwCRz.png)

## Sample configurations

### Minimal
```vim
call wilder#enable_cmdline_enter()
set wildcharm=<Tab>

cmap <expr> <Tab> wilder#in_context() ? wilder#next() : "\<Tab>"
cmap <expr> <S-Tab> wilder#in_context() ? wilder#previous() : "\<S-Tab>"
nnoremap <expr> <Leader>w wilder#toggle()
```

### Pipeline: Python Async Search
`nvim` only
```vim
" add minimal configuration

call wilder#set_option('pipeline', [
      \ wilder#python_fuzzy_delimiter(),
      \ wilder#python_search(),
      \ ])
```

### Pipeline: Auto Cmdline wildmenu
`nvim` only
```vim
" add minimal configuration

call wilder#set_option('pipeline', [
      \ wilder#branch(
      \   wilder#cmdline_pipeline(),
      \   [
      \     wilder#python_fuzzy_delimiter(),
      \     wilder#python_search(),
      \   ],
      \ )])
```

### Renderer: vim-airline Style
```vim
" add minimal configuration
" add pipeline configuration

call wilder#set_option('renderer', wilder#statusline_renderer({
      \ 'hl': 'airline_c',
      \ 'left': [
      \    wilder#string(' COMMAND ', 'airline_a'),
      \    wilder#separator('', 'airline_a', 'airline_c', 'left'), ' ',
      \ ],
      \ 'right': [
      \    ' ', wilder#separator('', 'airline_z','airline_c', 'right'),
      \    wilder#index({'hl': 'airline_z'}),
      \ ],
      \ }))

```
Experimental for `nvim v0.4`: `wilder#float_renderer`, arguments are the same
