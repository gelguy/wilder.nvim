function! wilder#renderer#popupmenu_popup#make(args) abort
  let l:state = wilder#renderer#popupmenu#prepare_state(a:args)
  let l:state.prop_types = {}
  let l:state.dummy_buf = -1

  return {
        \ 'render': {ctx, result -> s:render(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:render(state, ctx, result) abort
  call wilder#renderer#popupmenu#prepare_render(a:state, a:ctx, a:result)

  if a:state.page == [-1, -1] && !has_key(a:ctx, 'error')
    call popup_hide(a:state.win)
    redraw
    return
  endif

  let l:in_completion = 0
  try
    call setbufline(a:state.dummy_buf, 1, '')
  catch /E578/
    " popup showing counts as being in completion
    let l:in_completion = 1
  endtry

  if has_key(a:ctx, 'error')
    if l:in_completion
      call timer_start(0, {-> s:draw_error(a:state, a:ctx)})
    else
      call s:draw_error(a:state, a:ctx)
    endif
    return
  endif

  if !a:ctx.done && !a:state.dynamic
    return
  endif

  let [l:lines, l:expected_width] = wilder#renderer#popupmenu#make_lines(a:state, a:ctx, a:result)

  " +1 to account for the cmdline prompt.
  " -1 to shift left by 1 column for the added padding.
  let l:pos = get(a:result, 'pos', 0)

  let l:reverse = a:state.reverse

  if l:in_completion
    call timer_start(0, {-> s:render_lines(a:state, l:lines, l:expected_width, l:pos, a:ctx.selected, l:reverse)})
  else
    call s:render_lines(a:state, l:lines, l:expected_width, l:pos, a:ctx.selected, l:reverse)
  endif
endfunction

function! s:render_lines(state, lines, width, pos, selected, reverse) abort
  if a:state.win == -1
    call s:open_win(a:state)
  endif

  if empty(a:lines)
    call popup_hide(a:state.win)
    return
  else
    call popup_show(a:state.win)
  endif

  call s:clear_props(a:state)
  call deletebufline(a:state.buf, 1, '$')

  let l:lines = a:reverse ? reverse(a:lines) : a:lines

  let [l:page_start, l:page_end] = a:state.page

  let l:height = l:page_end - l:page_start + 1

  let l:col = a:pos % &columns
  if l:col + a:width > &columns
    let l:col = &columns - a:width
  endif
  if l:col < 0
    let l:col = 0
  endif

  " For Vim, if cmdline exceeds cmdheight, the screen lines are pushed up
  " similar to :mess, so we draw the popupmenu just above the cmdline.
  " Lines exceeding cmdheight do not count into target line number.
  let l:row = &lines - &cmdheight - l:height

  call popup_move(a:state.win, {
        \ 'line': l:row + 1,
        \ 'col': l:col + 1,
        \ 'minwidth': a:width,
        \ 'maxwidth': a:width,
        \ 'minheight': l:height,
        \ 'maxheight': l:height,
        \ })
  call popup_setoptions(a:state.win, {
        \ 'wrap': 0,
        \ })

  let l:default_hl = a:state.highlights['default']
  let l:selected_hl = a:state.highlights['selected']

  let l:i = 0
  while l:i < len(l:lines)
    let l:chunks = l:lines[l:i]

    let l:text = ''
    for l:chunk in l:chunks
      let l:text .= l:chunk[0]
    endfor

    call setbufline(a:state.buf, l:i + 1, l:text)

    let l:is_selected = a:reverse ? 
          \ l:page_start + (len(l:lines) - l:i - 1) == a:selected :
          \ l:page_start + l:i == a:selected

    let l:start = 1
    for l:chunk in l:chunks
      if l:is_selected
        if len(l:chunk) == 1
          let l:hl = l:selected_hl
        elseif len(l:chunk) == 2
          let l:hl = l:chunk[1]
        else
          let l:hl = l:chunk[2]
        endif
      else
        let l:hl = get(l:chunk, 1, l:default_hl)
      endif

      let l:length = len(l:chunk[0])

      if l:hl !=# l:default_hl
        call s:add_prop(a:state, l:hl, l:i + 1, l:start, l:length)
      endif

      let l:start += l:length
    endfor

    let l:i += 1
  endwhile

  call wilder#renderer#redraw(a:state.apply_incsearch_fix)
endfunction

function! s:pre_hook(state, ctx) abort
  if a:state.buf == -1 || !bufexists(a:state.buf)
    let a:state.buf = s:new_buf('[Wilder Popupmenu ' . localtime() . ']')
  endif

  if a:state.dummy_buf == -1 || !bufexists(a:state.dummy_buf)
    let a:state.dummy_buf = s:new_buf('[Wilder Popupmenu Dummy ' . localtime() . ']')
  endif

  for l:Column in a:state.left + a:state.right
    if type(l:Column) is v:t_dict &&
          \ has_key(l:Column, 'pre_hook')
      call l:Column['pre_hook'](a:ctx)
    endif
  endfor
endfunction

function! s:new_buf(bufname)
  let l:old_shortmess = &shortmess
  set shortmess+=F

  let l:buf = bufadd(a:bufname)
  call bufload(l:buf)

  call setbufvar(l:buf, '&buftype', 'nofile')
  call setbufvar(l:buf, '&bufhidden', 1)
  call setbufvar(l:buf, '&swapfile', 0)
  call setbufvar(l:buf, '&undolevels', -1)

  let &shortmess = l:old_shortmess

  return l:buf
endfunction

function! s:post_hook(state, ctx) abort
  if a:state.buf != -1
    call s:clear_props(a:state)
  endif

  if a:state.win != -1
    call popup_hide(a:state.win)
  endif

  for l:Column in a:state.left + a:state.right
    if type(l:Column) is v:t_dict &&
          \ has_key(l:Column, 'post_hook')
      call l:Column['post_hook'](a:ctx)
    endif
  endfor

  if getcmdtype() ==# ':'
    redraw
  else
    call timer_start(0, {-> execute('redraw')})
  endif
endfunction

function! s:draw_error(state, ctx) abort
  if a:state.win == -1
    call s:open_win(a:state)
  endif

  call popup_show(a:state.win)
  call s:clear_props(a:state)
  call deletebufline(a:state.buf, 1, '$')

  let l:error = wilder#render#to_printable(a:ctx.error)
  let [l:height, l:width] = wilder#renderer#popupmenu#get_error_dimensions(a:state, l:error)

  let l:row = &lines - &cmdheight - l:height

  call popup_move(a:state.win, {
        \ 'line': l:row + 1,
        \ 'col': 1,
        \ 'minwidth': l:width,
        \ 'maxwidth': l:width,
        \ 'minheight': l:height,
        \ 'maxheight': l:height,
        \ })
  call popup_setoptions(a:state.win, {
        \ 'wrap': 1,
        \ })

  let l:hl = a:ctx.highlights['error']

  call setbufline(a:state.buf, 1, l:error)
  call s:add_prop(a:state, l:hl, 1, 1, len(l:error))

  redraw
endfunction

function! s:open_win(state) abort
  " Dimensions and position will be updated later.
  let l:win = popup_create(a:state.buf, {
        \ 'line': 1,
        \ 'col': 1,
        \ 'fixed': 1,
        \ 'wrap': 0,
        \ 'scrollbar': 0,
        \ 'cursorline': 0,
        \ 'highlight': a:state.highlights.default,
        \ })

  let a:state.win = l:win
endfunction

function! s:clear_props(state) abort
  if a:state.buf == -1
    return
  endif

  let l:prop_types = prop_type_list({'bufnr': a:state.buf})
  for l:prop_type in l:prop_types
    call prop_type_delete(l:prop_type, {'bufnr': a:state.buf})
  endfor

  let a:state.prop_types = {}
endfunction

function! s:add_prop(state, hl, line, start, length) abort
  let l:prop_type = 'WilderProp_' . a:hl

  if !has_key(a:state.prop_types, a:hl)
    call prop_type_add(l:prop_type, {
          \ 'bufnr': a:state.buf,
          \ 'highlight': a:hl,
          \ 'combine': 0,
          \ })

    let a:state.prop_types[a:hl] = 1
  endif

  if a:length > 0
    call prop_add(a:line, a:start, {
          \ 'bufnr': a:state.buf,
          \ 'length': a:length,
          \ 'type': l:prop_type,
          \ })
  endif
endfunction
