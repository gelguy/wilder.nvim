function! wilder#render#renderer#mux#make(opts) abort
  let l:state = {
        \ ':': a:opts[':'],
        \ '/': a:opts['/'],
        \ '_current': 0,
        \ }

  if has_key(a:opts, 'substitute')
    let l:state._substitute = a:opts.substitute
  endif

  if !has_key(a:opts, '?') && has_key(a:opts, '/')
    let l:state['?'] = a:opts['/']
  endif

  return {
        \ 'render': {ctx, result -> s:render(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:render(state, ctx, result)
  let l:cmdtype = getcmdtype()
  let l:renderer = has_key(a:state, l:cmdtype) ?
        \ a:state[l:cmdtype] :
        \ 0

  if l:cmdtype ==# ':'
    let l:parsed = wilder#cmdline#parse(getcmdline())

    if wilder#cmdline#is_substitute_command(l:parsed.cmd) &&
          \ has_key(a:state, '_substitute')
      let l:renderer = a:state._substitute
    endif
  endif

  if l:renderer isnot a:state._current
    if a:state._current isnot 0
      call a:state._current.post_hook({})
    endif

    if l:renderer isnot 0
      call l:renderer.pre_hook({})
    endif

    let a:state._current = l:renderer
  endif

  if l:renderer is 0
    return
  endif

  call l:renderer.render(a:ctx, a:result)
endfunction

function! s:pre_hook(state, ctx)
  let l:cmdtype = getcmdtype()

  if has_key(a:state, l:cmdtype)
    let l:renderer = a:state[l:cmdtype]
  else
    let l:renderer = 0
  endif

  let a:state._current = l:renderer

  if l:renderer is 0
    return
  endif

  if has_key(l:renderer, 'pre_hook')
    call l:renderer.pre_hook(a:ctx)
  endif
endfunction

function! s:post_hook(state, ctx)
  let l:renderer = a:state._current

  if l:renderer is 0
    return
  endif

  let a:state._current = 0

  if has_key(l:renderer, 'post_hook')
    call l:renderer.post_hook(a:ctx)
  endif
endfunction
