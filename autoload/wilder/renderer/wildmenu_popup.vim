function! wilder#renderer#wildmenu_popup#make(args) abort
  let l:state = wilder#renderer#wildmenu#prepare_state(a:args)
  let l:state.buf = -1
  let l:state.win = -1
  let l:state.prop_types = {}

  return {
        \ 'render': {ctx, result -> s:render(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:render(state, ctx, result) abort
  if a:state.win == -1
    return
  endif

  if !a:ctx.done && !a:state.dynamic
    return
  endif

  let l:chunks = wilder#renderer#wildmenu#make_hl_chunks(
        \ a:state, &columns, a:ctx, a:result)

  let l:in_completion = 0
  try
    call setbufline(a:state.buf, 1, '')
  catch /E578/
    " popup showing counts as being in completion
    let l:in_completion = 1
  endtry

  if l:in_completion
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

  if a:state.cmdheight != &cmdheight
    call popup_move(a:state.win, {
          \ 'line': &lines - &cmdheight,
          \ 'minwidth': &columns,
          \ 'maxwidth': &columns,
          \ })
    let a:state.cmdheight = &cmdheight
  endif

  let l:text = ''
  for l:elem in a:chunks
    let l:text .= l:elem[0]
  endfor

  call setbufline(a:state.buf, 1, l:text)
  call s:clear_props(a:state)

  let l:start = 1
  for l:elem in a:chunks
    let l:hl = get(l:elem, 1, a:state.highlights['default'])
    let l:prop_type = 'WilderProp_' . l:hl

    if !has_key(a:state.prop_types, l:hl)
      call prop_type_add(l:prop_type, {
            \ 'bufnr': a:state.buf,
            \ 'highlight': l:hl,
            \ 'combine': 0,
            \ })

      let a:state.prop_types[l:hl] = 1
    endif

    let l:length = len(l:elem[0])
    if l:length > 0
      call prop_add(1, l:start, {
            \ 'bufnr': a:state.buf,
            \ 'length': l:length,
            \ 'type': l:prop_type,
            \ })
    endif

    let l:start += l:length
  endfor

  redraw
endfunction

function! s:new_win(buf) abort
  let l:win = popup_create(a:buf, {
        \ 'line': &lines - &cmdheight,
        \ 'col': 0,
        \ 'minheight': 1,
        \ 'maxheight': 1,
        \ 'minwidth': &columns,
        \ 'maxwidth': &columns,
        \ 'fixed': 1,
        \ 'wrap': 0,
        \ 'scrollbar': 0,
        \ 'cursorline': 0,
        \ })

  return l:win
endfunction

function! s:pre_hook(state, ctx) abort
  if a:state.buf == -1 || !bufexists(a:state.buf)
    let l:old_shortmess = &shortmess
    set shortmess+=F

    let a:state.buf = bufadd('[Wilder Wildmenu ' . localtime() . ']')
    call bufload(a:state.buf)

    call setbufvar(a:state.buf, '&buftype', 'nofile')
    call setbufvar(a:state.buf, '&bufhidden', 1)
    call setbufvar(a:state.buf, '&swapfile', 0)
    call setbufvar(a:state.buf, '&undolevels', -1)

    let &shortmess = l:old_shortmess
  endif

  if a:state.win == -1
    let a:state.win = s:new_win(a:state.buf)
  elseif a:state.columns != &columns ||
        \ a:state.cmdheight != &cmdheight
    call popup_move(a:state.win, {
          \ 'line': &lines - &cmdheight,
          \ 'minwidth': &columns,
          \ 'maxwidth': &columns,
          \ })
  endif

  call popup_show(a:state.win)

  call wilder#renderer#wildmenu#item_pre_hook(a:state.left, a:ctx)
  call wilder#renderer#wildmenu#item_pre_hook(a:state.right, a:ctx)
endfunction

function! s:post_hook(state, ctx) abort
  call s:clear_props(a:state)

  if a:state.win != -1
    call popup_hide(a:state.win)
  endif

  call wilder#renderer#wildmenu#item_post_hook(a:state.left, a:ctx)
  call wilder#renderer#wildmenu#item_post_hook(a:state.right, a:ctx)

  if getcmdtype() ==# ':'
    " Avoid redrawing from timer since there might be commands which print
    " messages e.g. echo.
    redraw
  else
    " Redraw from timer to avoid hlsearch flashing.
    call timer_start(0, {-> execute('redraw')})
  endif
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
