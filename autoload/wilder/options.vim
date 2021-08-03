let s:opts = {}

" main options
call extend(s:opts, {
      \ 'modes': ['/', '?'],
      \ 'use_python_remote_plugin': has('nvim') && has('python3'),
      \ 'use_cmdlinechanged': exists('##CmdlineChanged'),
      \ 'interval': 100,
      \ 'before_cursor': 0,
      \ 'num_workers': 2,
      \ })

function! wilder#options#get(...) abort
  if !a:0
    return s:opts
  endif

  return s:opts[a:1]
endfunction

function! wilder#options#set(x, ...) abort
  if len(a:000) == 0
    call extend(s:opts, a:x)
  else
    let s:opts[a:x] = a:1
  endif

  if !has('nvim') && s:opts['use_python_remote_plugin']
    call wilder#yarp#init()
  endif
endfunction
