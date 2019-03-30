let s:open_win_num_args = 3
try
  let l:win = nvim_open_win(0, 0, {})
catch 'Not enough arguments'
  let s:open_win_num_args = 5
catch
endtry

function! wilder#render#float#renderer(args) abort
  let l:state = {
        \ 'hl': get(a:args, 'hl', 'StatusLine'),
        \ 'selected_hl': get(a:args, 'selected_hl', 'WildMenu'),
        \ 'error_hl': get(a:args, 'error_hl', 'StatusLine'),
        \ 'separator': wilder#render#to_printable(get(a:args, 'separator', ' ')),
        \ 'ellipsis': wilder#render#to_printable(get(a:args, 'ellipsis', '...')),
        \ 'page': [-1, -1],
        \ 'buf': -1,
        \ 'win': -1,
        \ 'ns_id': nvim_create_namespace(''),
        \ 'columns': -1,
        \ 'cmdheight': -1,
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

  if a:state.win == -1
    return
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

  let l:chunks = wilder#render#make_hl_chunks(a:state.left, a:state.right, a:ctx, a:xs)

  let l:in_sandbox = 0
  try
    call nvim_buf_set_lines(a:state.buf, 0, -1, v:true, [])
  catch /E523/
    " might be in sandbox due to expr mapping
    let l:in_sandbox = 1
  endtry

  if l:in_sandbox
    call timer_start(0, {-> s:render_chunks(a:state, l:chunks)})
  else
    call s:render_chunks(a:state, l:chunks)
  endif
endfunction

function! s:render_chunks(state, chunks) abort
  if a:state.win == -1
    return
  endif

  let a:state.columns = &columns
  let a:state.cmdheight = &cmdheight

  let l:text = ''
  for l:elem in a:chunks
    let l:text .= l:elem[0]
  endfor

  call nvim_buf_set_lines(a:state.buf, 0, -1, v:true, [l:text])
  call nvim_buf_clear_namespace(a:state.buf, a:state.ns_id, 0, -1)

  let l:start = 0
  for l:elem in a:chunks
    let l:end = l:start + len(l:elem[0])

    let l:hl = get(l:elem, 1, a:state.hl)
    call nvim_buf_add_highlight(a:state.buf, a:state.ns_id, l:hl, 0, l:start, l:end)

    let l:start = l:end
  endfor

  redraw
endfunction

function! s:new_win(buf) abort
  if s:open_win_num_args == 5
    let l:win = nvim_open_win(a:buf, 0, &columns, 1, {
          \ 'relative': 'editor',
          \ 'row': &lines - &cmdheight - 1,
          \ 'col': 0,
          \ 'focusable': 0,
          \ })
  else
    let l:win = nvim_open_win(a:buf, 0, {
          \ 'relative': 'editor',
          \ 'height': 1,
          \ 'width': &columns,
          \ 'row': &lines - &cmdheight - 1,
          \ 'col': 0,
          \ 'focusable': 0,
          \ })
  endif

  call nvim_win_set_option(l:win, 'winhl', 'Normal:Normal,Search:None,IncSearch:None')
  call nvim_win_set_option(l:win, 'listchars', '')

  return l:win
endfunction

function! s:pre_hook(state, ctx) abort
  if a:state.buf == -1
    let a:state.buf = nvim_create_buf(v:false, v:true)
  endif

  if a:state.win == -1
    let a:state.win = s:new_win(a:state.buf)
  elseif a:state.columns != &columns || a:state.cmdheight != &cmdheight
    let l:win = s:new_win(a:state.buf)
    call nvim_win_close(a:state.win, 1)
    let a:state.win = l:win
  endif

  call wilder#render#components_pre_hook(a:state.left + a:state.right, a:ctx)
endfunction

function! s:post_hook(state, ctx) abort
  if a:state.buf != -1
    call nvim_buf_clear_namespace(a:state.buf, a:state.ns_id, 0, -1)
  endif

  if a:state.win != -1
    call nvim_win_close(a:state.win, 1)
    let a:state.win = -1
  endif

  call wilder#render#components_post_hook(a:state.left + a:state.right, a:ctx)
endfunction
