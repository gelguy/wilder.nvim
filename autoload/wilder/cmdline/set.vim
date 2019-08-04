function! wilder#cmdline#set#get_bool_options() abort
  return s:bool_options_list
endfunction

function! wilder#cmdline#set#do(ctx) abort
  let a:ctx.expand = 'option'

  if a:ctx.pos == len(a:ctx.cmdline)
    return
  endif

  let l:arg_start = a:ctx.pos
  let l:p = len(a:ctx.cmdline) - 1

  while l:p > l:arg_start
    let l:s = l:p
    if a:ctx.cmdline[l:p] ==# ' ' || a:ctx.cmdline[l:p] ==# ','
      while l:s > l:arg_start && a:ctx.cmdline[l:s-1] ==# '\'
        let l:s -= 1
      endwhile

      if a:ctx.cmdline[l:p] ==# ' ' && (l:p - l:s) % 2 == 0
        let l:p += 1
        break
      endif
    endif

    let l:p -= 1
  endwhile

  if a:ctx.cmdline[l:p : l:p+1] ==# 'no'
    let l:p += 2
    let a:ctx.expand = 'option_bool'
  endif

  if a:ctx.cmdline[l:p : l:p+2] ==# 'inv'
    let l:p += 3
    let a:ctx.expand = 'option_bool'
  endif

  let a:ctx.pos = l:p

  " skip termkeys and termcap options

  while l:p < len(a:ctx.cmdline)
    let l:char = a:ctx.cmdline[l:p]
    if !(l:char >=# 'a' && l:char <=# 'z' ||
          \ l:char >=# 'A' && l:char <=# 'Z' ||
          \ l:char >=# '0' && l:char <=# '9') &&
          \ l:char !=# '_' &&
          \ l:char !=# '*'
      break
    endif

    let l:p += 1
  endwhile

  if l:p == len(a:ctx.cmdline)
    return
  endif

  let l:option_name = a:ctx.cmdline[a:ctx.pos : l:p - 1]
  let l:completions = getcompletion(l:option_name, 'option')
  if empty(l:completions)
    return
  endif

  if len(l:completions) == 1
        \ && l:completions[0] ==# l:option_name
        \ && get(s:bool_options, l:option_name, 0)
    let a:ctx.expand = 'nothing'
    return
  endif

  let a:ctx.option = l:option_name
  let l:char = a:ctx.cmdline[l:p]

  if (l:char ==# '-' || l:char ==# '+' || l:char ==# '^') &&
        \ l:p < len(a:ctx.cmdline) &&
        \ a:ctx.cmdline[l:p] ==# '='
    let l:char = '='
    let l:p += 1
  endif

  if l:char !=# '=' && l:char !=# ':' ||
        \ a:ctx.expand ==# 'option_bool'
    let a:ctx.expand = 'unsuccessful'
    return
  endif

  if l:p + 1 == len(a:ctx.cmdline)
    let a:ctx.expand = 'option_old'
    let a:ctx.pos = l:p + 1
  endif
endfunction

let s:bool_options = {
      \ 'autochdir': 1,
      \ 'autoread': 1,
      \ 'autowrite': 1,
      \ 'autowriteall': 1,
      \ 'backup': 1,
      \ 'delcombine': 1,
      \ 'confirm': 1,
      \ 'compatible': 1,
      \ 'cscoperelative': 1,
      \ 'cscopetag': 1,
      \ 'cscopeverbose': 1,
      \ 'digraph': 1,
      \ 'edcompatible': 1,
      \ 'emoji': 1,
      \ 'equalalways': 1,
      \ 'errorbells': 1,
      \ 'exrc': 1,
      \ 'fileignorecase': 1,
      \ 'fsync': 1,
      \ 'gdefault': 1,
      \ 'prompt': 1,
      \ 'hidden': 1,
      \ 'hlsearch': 1,
      \ 'hkmap': 1,
      \ 'hkmapp': 1,
      \ 'arabicshape': 1,
      \ 'icon': 1,
      \ 'ignorecase': 1,
      \ 'incsearch': 1,
      \ 'insertmode': 1,
      \ 'joinspaces': 1,
      \ 'langnoremap': 1,
      \ 'langremap': 1,
      \ 'lazyredraw': 1,
      \ 'loadplugins': 1,
      \ 'magic': 1,
      \ 'more': 1,
      \ 'paste': 1,
      \ 'remap': 1,
      \ 'allowrevins': 1,
      \ 'revins': 1,
      \ 'ruler': 1,
      \ 'secure': 1,
      \ 'shelltemp': 1,
      \ 'shellslash': 1,
      \ 'shiftround': 1,
      \ 'showcmd': 1,
      \ 'showfulltag': 1,
      \ 'showmatch': 1,
      \ 'showmode': 1,
      \ 'smartcase': 1,
      \ 'smarttab': 1,
      \ 'splitbelow': 1,
      \ 'splitright': 1,
      \ 'startofline': 1,
      \ 'warn': 1,
      \ 'wildignorecase': 1,
      \ 'wildmenu': 1,
      \ 'wrapscan': 1,
      \ 'write': 1,
      \ 'writeany': 1,
      \ 'writebackup': 1,
      \ }

let s:bool_options_list = sort(keys(s:bool_options))

" excluding term options
let s:term_options = {
      \ 'tagbsearch': 0,
      \ 'tagrelative': 0,
      \ 'tagstack': 0,
      \ 'termbidi': 0,
      \ 'terse': 0,
      \ 'tildeop': 0,
      \ 'timeout': 0,
      \ 'title': 0,
      \ 'termguicolors': 0,
      \ 'ttimeout': 0,
      \ 'visualbell': 0,
      \ }
