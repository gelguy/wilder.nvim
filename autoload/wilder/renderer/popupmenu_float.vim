function! wilder#renderer#popupmenu_float#make(args) abort
  let l:state = wilder#renderer#popupmenu#prepare_state(a:args)
  let l:state.winblend = get(a:args, 'winblend', 0)
  let l:state.ns_id = nvim_create_namespace('')

  return {
        \ 'render': {ctx, result -> s:render(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:render(state, ctx, result) abort
  call wilder#renderer#popupmenu#prepare_render(a:state, a:ctx, a:result)

  if a:state.page == [-1, -1] && !has_key(a:ctx, 'error')
    call s:close_win(a:state)
    return
  endif

  call nvim_buf_clear_namespace(a:state.buf, a:state.ns_id, 0, -1)

  let l:in_sandbox = 0
  try
    call nvim_buf_set_lines(a:state.buf, 0, -1, v:true, [])
  catch /E523/
    " might be in sandbox due to expr mapping
    let l:in_sandbox = 1
  endtry

  if has_key(a:ctx, 'error')
    if l:in_sandbox
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

  if l:in_sandbox
    call timer_start(0, {-> s:render_lines(a:state, l:lines, l:expected_width, l:pos, a:ctx.selected, l:reverse)})
  else
    call s:render_lines(a:state, l:lines, l:expected_width, l:pos, a:ctx.selected, l:reverse)
  endif
endfunction

function! s:render_lines(state, lines, width, pos, selected, reverse) abort
  if a:state.win == -1
    call s:open_win(a:state)
  endif

  let l:lines = a:reverse ? reverse(a:lines) : a:lines

  let [l:page_start, l:page_end] = a:state.page

  let l:height = l:page_end - l:page_start + 1

  let l:col = a:pos % &columns

  " Always show the pum above the cmdline.
  let l:cmdheight = s:get_cmdheight()
  let l:row = &lines - l:cmdheight - l:height

  call nvim_win_set_config(a:state.win, {
        \ 'relative': 'editor',
        \ 'row': l:row,
        \ 'col': l:col,
        \ 'height': l:height,
        \ 'width': a:width,
        \ })

  call nvim_win_set_option(a:state.win, 'wrap', v:false)

  let l:default_hl = a:state.highlights['default']
  let l:selected_hl = a:state.highlights['selected']

  let l:i = 0
  while l:i < len(l:lines)
    let l:chunks = l:lines[l:i]

    let l:text = ''
    for l:chunk in l:chunks
      let l:text .= l:chunk[0]
    endfor

    call nvim_buf_set_lines(a:state.buf, l:i, l:i, v:true, [l:text])

    let l:is_selected = a:reverse ? 
          \ l:page_start + (len(l:lines) - l:i - 1) == a:selected :
          \ l:page_start + l:i == a:selected

    let l:start = 0
    for l:chunk in l:chunks
      let l:end = l:start + len(l:chunk[0])

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

      if l:hl !=# l:default_hl
        call nvim_buf_add_highlight(a:state.buf, a:state.ns_id, l:hl, l:i, l:start, l:end)
      endif

      let l:start = l:end
    endfor

    let l:i += 1
  endwhile

  call wilder#renderer#redraw(a:state.apply_incsearch_fix)
endfunction

function! s:pre_hook(state, ctx) abort
  if a:state.buf == -1 || !bufexists(a:state.buf)
    let a:state.buf = nvim_create_buf(v:false, v:true)
    call nvim_buf_set_name(a:state.buf, '[Wilder Popupmenu ' . localtime() . ']')
  endif

  for l:Column in a:state.left + a:state.right
    if type(l:Column) is v:t_dict &&
          \ has_key(l:Column, 'pre_hook')
      call l:Column['pre_hook'](a:ctx)
    endif
  endfor
endfunction

function! s:post_hook(state, ctx) abort
  if a:state.buf != -1
    call nvim_buf_clear_namespace(a:state.buf, a:state.ns_id, 0, -1)
  endif

  if a:state.win != -1
    call s:close_win(a:state)
  endif

  for l:Column in a:state.left + a:state.right
    if type(l:Column) is v:t_dict &&
          \ has_key(l:Column, 'post_hook')
      call l:Column['post_hook'](a:ctx)
    endif
  endfor
endfunction

function! s:draw_error(state, ctx) abort
  if a:state.win == -1
    call s:open_win(a:state)
  endif

  let l:error = wilder#render#to_printable(a:ctx.error)
  let [l:height, l:width] = wilder#renderer#popupmenu#get_error_dimensions(a:state, l:error)

  " Always show the pum above the cmdline.
  let l:cmdheight = s:get_cmdheight()
  let l:row = &lines - l:cmdheight - l:height

  call nvim_win_set_config(a:state.win, {
        \ 'relative': 'editor',
        \ 'row': l:row,
        \ 'col': 0,
        \ 'height': l:height,
        \ 'width': l:width,
        \ })

  call nvim_win_set_option(a:state.win, 'wrap', v:true)

  let l:hl = a:ctx.highlights['error']

  call nvim_buf_set_lines(a:state.buf, 0, -1, v:true, [l:error])
  call nvim_buf_add_highlight(a:state.buf, a:state.ns_id, l:hl, 0, 0, -1)

  redraw
endfunction

function! s:close_win(state) abort
  if a:state.win == -1
    return
  endif

  let l:win = a:state.win
  let a:state.win = -1
  " cannot call nvim_win_close() while cmdline-window is open
  if getcmdwintype() ==# ''
    call nvim_win_close(l:win, 1)
    call timer_start(0, {-> execute('redraw')})
  else
    execute 'autocmd CmdWinLeave * ++once call timer_start(0, {-> nvim_win_close(' . l:win . ', 0)})'
  endif
endfunction

function! s:open_win(state) abort
  " Dimensions and position will be updated later.
  let l:win = nvim_open_win(a:state.buf, 0, {
        \ 'relative': 'editor',
        \ 'height': 1,
        \ 'width': 1,
        \ 'row': &lines - 1,
        \ 'col': 0,
        \ 'focusable': 0,
        \ 'style': 'minimal',
        \ })

  call nvim_win_set_option(l:win, 'winblend', a:state.winblend)
  call nvim_win_set_option(l:win, 'winhighlight',
        \ 'Search:None,IncSearch:None,Normal:' . a:state.highlights['default'])

  let a:state.win = l:win
endfunction

function! s:get_cmdheight() abort
  " Always show the pum above the cmdline.
  let l:cmdheight = (strdisplaywidth(getcmdline()) + 1) / &columns + 1
  if l:cmdheight < &cmdheight
    let l:cmdheight = &cmdheight
  elseif l:cmdheight > 1
    " Show the pum above the msgsep.
    let l:has_msgsep = stridx(&display, 'msgsep') >= 0

    if l:has_msgsep
      let l:cmdheight += 1
    endif
  endif

  return l:cmdheight
endfunction
