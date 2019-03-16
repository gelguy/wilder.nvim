let s:opts = {}

" main options
call extend(s:opts, {
      \ 'modes': ['/', '?'],
      \ 'interval': 100,
      \ 'use_cmdlinechanged': 0,
      \ 'renderer': 'statusline',
      \ 'hooks': {
      \    'pre': 'wilder#main#pre_hook',
      \    'post': 'wilder#main#post_hook',
      \  },
      \ 'num_workers': 2,
      \ })

" render options
call extend(s:opts, {
      \ 'hl': 'StatusLine',
      \ 'selected_hl': 'WildMenu',
      \ 'error_hl': 'StatusLine',
      \ 'separator': ' ',
      \ 'ellipsis': '...',
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
