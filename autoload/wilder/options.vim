let s:opts = {}

" main options
call extend(s:opts, {
      \ 'modes': ['/', '?'],
      \ 'use_cmdlinechanged': exists('##CmdlineChanged'),
      \ 'interval': 100,
      \ 'before_cursor': 0,
      \ 'num_workers': 2,
      \ })

if has('nvim')
  let s:opts.use_python_remote_plugin = has('python3')
elseif !has('python3')
  let s:opts.use_python_remote_plugin = 0
endif

function! wilder#options#get(...) abort
  if !a:0
    return s:opts
  endif

  if a:1 ==# 'use_python_remote_plugin' &&
        \ !has_key(s:opts, 'use_python_remote_plugin')
    try
      silent call yarp#py3()
    catch /E119/
      " success
      let s:opts.use_python_remote_plugin = 1
    catch
      " fail
      let s:opts.use_python_remote_plugin = 0
    endtry
  endif

  return s:opts[a:1]
endfunction

function! wilder#options#set(x, ...) abort
  if len(a:000) == 0
    call extend(s:opts, a:x)
  else
    let s:opts[a:x] = a:1
  endif
endfunction
