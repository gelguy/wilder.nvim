let s:ns_id = nvim_create_namespace('')

let s:buf = -1
let s:win = -1
let s:columns = -1
let s:cmdheight = -1

function! wilder#render#float#renderer(args) abort
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
        \ 'draw': {ctx, xs -> s:draw(l:state, ctx, xs)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:draw(state, ctx, xs) abort
  if a:ctx.clear_previous
    let a:state.page = [-1, -1]
  endif

  let l:space_used = wilder#render#components_len(
        \ a:state.left + a:state.right,
        \ a:ctx,
        \ a:xs)

  let a:ctx.space = &columns - l:space_used
  let a:ctx.page = a:state.page
  let a:ctx.separator = a:state.separator
  let a:ctx.ellipsis = a:state.ellipsis

  let l:page = wilder#render#make_page(a:ctx, a:xs)
  let a:ctx.page = l:page
  let a:state.page = l:page

  let a:ctx.hl = a:state.hl
  let a:ctx.selected_hl = a:state.selected_hl
  let a:ctx.error_hl = a:state.error_hl

  let l:chunks = wilder#render#chunks(a:state.left, a:state.right, a:ctx, a:xs)

  call s:draw_chunks(a:state.hl, l:chunks)
endfunction

function! s:draw_chunks(hl, chunks) abort
  if s:buf == -1
    let s:buf = nvim_create_buf(v:false, v:true)
  endif

  if s:win == -1
    let s:win = s:new_win()
  elseif s:columns != &columns || s:cmdheight != &cmdheight
    let l:win = s:new_win()
    call nvim_win_close(s:win, 1)
    let s:win = l:win
  endif

  let s:columns = &columns
  let s:cmdheight = &cmdheight

  let l:text = ''
  for l:elem in a:chunks
    let l:text .= l:elem[0]
  endfor

  call nvim_buf_set_lines(s:buf, 0, -1, v:true, [l:text])

  let l:start = 0
  for l:elem in a:chunks
    let l:end = l:start + len(l:elem[0])

    let l:hl = get(l:elem, 1, a:hl)
    call nvim_buf_add_highlight(s:buf, s:ns_id, l:hl, 0, l:start, l:end)

    let l:start = l:end
  endfor

  redraw
endfunction

function! s:new_win() abort
  let l:win = nvim_open_win(s:buf, 0, &columns, 1, {
        \ 'relative': 'editor',
        \ 'row': &lines - &cmdheight - 1,
        \ 'col': 0,
        \ 'focusable': 0,
        \ })

  call nvim_win_set_option(l:win, 'winhl', 'Normal:Normal,Search:None,IncSearch:None')
  call nvim_win_set_option(l:win, 'listchars', '')

  return l:win
endfunction

function! s:pre_hook(state, ctx) abort
  call wilder#render#components_pre_hook(a:state.left + a:state.right, a:ctx)
endfunction

function! s:post_hook(state, ctx) abort
  if s:buf != -1
    call nvim_buf_clear_namespace(s:buf, s:ns_id, 0, -1)
  endif

  if s:win != -1
    call nvim_win_close(s:win, 1)
    let s:win = -1
  endif

  call wilder#render#components_post_hook(a:state.left + a:state.right, a:ctx)
endfunction
