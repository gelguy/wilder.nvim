# wilder.nvim

A more adventurous wildmenu.

`wilder.nvim` adds new features to `wildmenu`.
Features include
- Automatically provides suggestions as you type
- `/` search support: get suggestions as you type your search query
- Customisable pipeline: e.g. choose between substring matching and fuzzy matching
- Async query support: use `python3` for faster queries
- Customisable skins and themes

![search](https://i.imgur.com/kjgwCRz.png)

# Requirements
- Vim 8.1+ or Neovim 0.3+
- Certain features (e.g. async, cmdline completion) are only enabled in Neovim
- Default async search needs Python 3 enabled

# Install
```
" with dein
call dein#add('gelguy/wilder.nvim')

" with vim-plug
Plug 'gelguy/wilder.nvim'
```

# Minimal init.vim/.vimrc Configuration

```vim
call wilder#enable_cmdline_enter()

set wildcharm=<Tab>
cmap <expr> <Tab> wilder#in_context() ? wilder#next() : "\<Tab>"
cmap <expr> <S-Tab> wilder#in_context() ? wilder#previous() : "\<S-Tab>"

" enable cmdline completion (for Neovim only)
call wilder#set_option('modes', ['/', '?', ':'])
```

# Disabling in the case of errors

Use `q:` to open the `cmdline-window` and enter the following command
```
call wilder#disable()
```

Alternatively, define a mapping in your `init.vim`
```
nnoremap <expr> <Leader>w wilder#toggle()
```
