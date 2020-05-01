function! wilder#render#renderer#statusline#make(args) abort
  let l:highlights = copy(get(a:args, 'highlights', {}))
  let l:state = {
        \ 'highlights': extend(l:highlights, {
        \   'default': get(a:args, 'hl', 'StatusLine'),
        \   'selected': get(a:args, 'selected_hl', 'WildMenu'),
        \   'error': get(a:args, 'error_hl', 'WildMenu'),
        \ }, 'keep'),
        \ 'separator': wilder#render#to_printable(get(a:args, 'separator', '  ')),
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

  if !has_key(l:state.highlights, 'separator')
    let l:state.highlights.separator = get(a:args, 'separator_hl', l:state.highlights['default'])
  endif

  return {
        \ 'render': {ctx, result -> s:render(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:render(state, ctx, result) abort
  if a:ctx.clear_previous
    let a:state.page = [-1, -1]
  endif

  let l:space_used = wilder#render#component_len(
        \ a:state.left,
        \ a:ctx,
        \ a:result)

  let l:space_used += wilder#render#component_len(
        \ a:state.right,
        \ a:ctx,
        \ a:result)

  let a:ctx.space = winwidth(0) - l:space_used
  let a:ctx.page = a:state.page
  let a:ctx.separator = a:state.separator
  let a:ctx.ellipsis = a:state.ellipsis

  let l:page = wilder#render#make_page(a:ctx, a:result)
  let a:ctx.page = l:page
  let a:state.page = l:page

  let a:ctx.highlights = a:state.highlights

  let l:chunks = wilder#render#make_hl_chunks(a:state.left, a:state.right, a:ctx, a:result)

  call s:render_chunks(l:chunks, a:state.highlights['default'])
endfunction

function! s:render_chunks(chunks, hl) abort
  let l:statusline = ''
  let g:_wilder_xs = map(copy(a:chunks), {_, x -> x[0]})

  let l:i = 0
  while l:i < len(a:chunks)
    let l:statusline .= '%#' . get(a:chunks[l:i], 1, a:hl) . '#'

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

  call wilder#render#component_pre_hook(a:state.left, a:ctx)
  call wilder#render#component_pre_hook(a:state.right, a:ctx)
endfunction

function! s:post_hook(state, ctx) abort
  let &laststatus = s:old_laststatus
  let &statusline = s:old_statusline

  call wilder#render#component_post_hook(a:state.left, a:ctx)
  call wilder#render#component_post_hook(a:state.right, a:ctx)
endfunction
