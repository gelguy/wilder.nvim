function! wilder#render#renderer#statusline#make(args) abort
  let l:state = wilder#render#renderer#prepare_state(a:args)

  return {
        \ 'render': {ctx, result -> s:render(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:render(state, ctx, result) abort
  let l:chunks = wilder#render#renderer#make_hl_chunks(a:state, a:ctx, a:result)

  call s:render_chunks(l:chunks, a:state.highlights['default'])
endfunction

function! s:render_chunks(chunks, hl) abort
  let l:statusline = ''
  let g:_wilder_xs = map(copy(a:chunks), {_, x -> x[0]})

  let l:i = 0
  while l:i < len(a:chunks)
    let l:statusline .= '%#' . get(a:chunks[l:i], 1, a:hl) . '#'

    if stridx(g:_wilder_xs[l:i], '%') >= 0
      " prevent leading space from being truncated
      if g:_wilder_xs[l:i][0] ==# ' '
        let l:statusline .= ' '
        let g:_wilder_xs[l:i] = g:_wilder_xs[l:i][1:]
      endif

      let l:statusline .= '%{g:_wilder_xs[' . string(l:i) . ']}'
    else
      let l:statusline .= g:_wilder_xs[l:i]
    endif

    let l:i += 1
  endwhile

  call setwinvar(0, '&statusline', l:statusline)

  redrawstatus
endfunction

function! s:pre_hook(state, ctx) abort
  let s:old_laststatus = &laststatus
  let &laststatus = 2
  let s:old_statusline = &statusline

  call wilder#render#component_pre_hook(a:state.left, a:ctx)
  call wilder#render#component_pre_hook(a:state.right, a:ctx)
endfunction

function! s:post_hook(state, ctx) abort
  let &laststatus = s:old_laststatus
  let &statusline = s:old_statusline
  redrawstatus

  call wilder#render#component_post_hook(a:state.left, a:ctx)
  call wilder#render#component_post_hook(a:state.right, a:ctx)
endfunction
