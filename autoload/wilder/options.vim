let s:opts = {}

" main options
call extend(s:opts, {
      \ 'modes': ['/', '?'],
      \ 'use_cmdlinechanged': exists('##CmdlineChanged'),
      \ 'interval': 100,
      \ 'before_cursor': 0,
      \ 'num_workers': 2,
      \ })

function! wilder#options#get() abort
  return s:opts
endfunction

function! wilder#options#set(x, ...) abort
  if len(a:000) == 0
    call extend(s:opts, a:x)
  else
    let s:opts[a:x] = a:1
  endif
endfunction
