function! wilder#render#statusline#renderer(args) abort
  let l:state = {
        \ 'hl': get(a:args, 'hl', 'StatusLine'),
        \ 'selected_hl': get(a:args, 'selected_hl', 'WildMenu'),
        \ 'error_hl': get(a:args, 'error_hl', 'StatusLine'),
        \ 'separator': wilder#render#to_printable(get(a:args, 'separator', ' ')),
        \ 'ellipsis': wilder#render#to_printable(get(a:args, 'ellipsis', '...')),
        \ 'page': [-1, -1],
        \ }

  if !has_key(a:args, 'left') && !has_key(a:args, 'right')
    let l:state.left = [wilder#previous_arrow()]
    let l:state.right = [wilder#next_arrow()]
  else
    let l:state.left = get(a:args, 'left', [])
    let l:state.right = get(a:args, 'right', [])
  endif

  return {
        \ 'render': {ctx, xs -> s:render(l:state, ctx, xs)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:render(state, ctx, xs) abort
  if a:ctx.clear_previous
    let a:state.page = [-1, -1]
  endif

  let l:space_used = wilder#render#components_len(
        \ a:state.left + a:state.right,
        \ a:ctx,
        \ a:xs)

  let a:ctx.space = winwidth(0) - l:space_used
  let a:ctx.page = a:state.page
  let a:ctx.separator = a:state.separator
  let a:ctx.ellipsis = a:state.ellipsis

  let l:page = wilder#render#make_page(a:ctx, a:xs)
  let a:ctx.page = l:page
  let a:state.page = l:page

  let a:ctx.hl = a:state.hl
  let a:ctx.selected_hl = a:state.selected_hl
  let a:ctx.error_hl = a:state.error_hl

  let l:chunks = wilder#render#make_hl_chunks(a:state.left, a:state.right, a:ctx, a:xs)

  call s:render_chunks(l:chunks)
endfunction

function! s:render_chunks(chunks) abort
  let l:statusline = ''
  let g:_wilder_xs = map(copy(a:chunks), {_, x -> x[0]})

  let l:i = 0
  while l:i < len(a:chunks)
    let l:statusline .= '%#' . a:chunks[l:i][1] . '#'

    " prevent leading space from being truncated
    if g:_wilder_xs[l:i][0] ==# ' '
      let l:statusline .= ' '
      let g:_wilder_xs[l:i] = g:_wilder_xs[l:i][1:]
    endif

    let l:statusline .= '%{g:_wilder_xs[' . string(l:i) . ']}'

    let l:i += 1
  endwhile

  call setwinvar(0, '&statusline', l:statusline)

  redrawstatus
endfunction

function! s:pre_hook(state, ctx) abort
  let s:old_laststatus = &laststatus
  let &laststatus = 2
  let s:old_statusline = &statusline

  call wilder#render#components_pre_hook(a:state.left + a:state.right, a:ctx)
endfunction

function! s:post_hook(state, ctx) abort
  let &laststatus = s:old_laststatus
  let &statusline = s:old_statusline

  call wilder#render#components_post_hook(a:state.left + a:state.right, a:ctx)
endfunction
