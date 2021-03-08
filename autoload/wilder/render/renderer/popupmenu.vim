function! s:prepare_state(opts) abort
  let l:highlights = copy(get(a:opts, 'highlights', {}))
  let l:state = {
        \ 'highlights': extend(l:highlights, {
        \   'default': get(a:opts, 'hl', 'Pmenu'),
        \   'selected': get(a:opts, 'selected_hl', 'PmenuSel'),
        \   'error': get(a:opts, 'error_hl', 'Error'),
        \ }, 'keep'),
        \ 'ellipsis': wilder#render#to_printable(get(a:opts, 'ellipsis', '...')),
        \ 'winblend': get(a:opts, 'winblend', 0),
        \ 'page': [-1, -1],
        \ 'buf': -1,
        \ 'win': -1,
        \ 'draw_cache': wilder#cache#cache(),
        \ 'apply_highlights_cache': wilder#cache#cache(),
        \ 'run_id': -1,
        \ 'longest_line_width': 0,
        \ 'ns_id': nvim_create_namespace(''),
        \ }

  let l:max_width = get(a:opts, 'max_width', '50%')
  if type(l:max_width) is v:t_number
    if l:max_width <= 0
      let l:max_width = 10000
    endif

    let l:state.get_max_width = {-> l:max_width}
  else
    let l:matches = matchlist(l:max_width, '^\(\d\+%\)$')
    if len(l:matches) >= 2
      let l:max_width_percent = 0.01 * str2nr(l:matches[1])
      let l:state.get_max_width = {-> float2nr(l:max_width_percent * &columns)}
    else
      let l:state.get_max_width = {-> 10000}
    endif
  endif

  let l:max_height = get(a:opts, 'max_height', '50%')
  if type(l:max_height) is v:t_number
    if l:max_height <= 0
      let l:max_height = 10000
    endif

    let l:state.get_max_height = {-> l:max_height}
  else
    let l:matches = matchlist(l:max_height, '^\(\d\+%\)$')
    if len(l:matches) >= 2
      let l:max_height_percent = 0.01 * str2nr(l:matches[1])
      let l:state.get_max_height = {-> float2nr(l:max_height_percent * &lines)}
    else
      let l:state.get_max_height = {-> 10000}
    endif
  endif

  let l:min_width = get(a:opts, 'min_width', 0)
  if type(l:min_width) is v:t_number
    let l:state.get_min_width = {-> l:min_width}
  else
    let l:matches = matchlist(l:min_width, '^\(\d\+%\)$')
    if len(l:matches) >= 2
      let l:min_width_percent = 0.01 * str2nr(l:matches[1])
      let l:state.get_min_width = {-> float2nr(l:min_width_percent * &columns)}
    else
      let l:state.get_min_width = {-> 0}
    endif
  endif

  if !has_key(a:opts, 'left') && !has_key(a:opts, 'right')
    let l:state.left = []
    let l:state.right = [' ', wilder#popupmenu_scrollbar()]
  else
    let l:state.left = get(a:opts, 'left', [])
    let l:state.right = get(a:opts, 'right', [])
  endif

  if !has_key(l:state.highlights, 'accent')
    let l:state.highlights.accent =
          \ wilder#hl_with_attr(
          \ 'WilderPoppupMenuAccent',
          \ l:state.highlights['default'],
          \ 'underline', 'bold')
  endif

  if !has_key(l:state.highlights, 'selected_accent')
    let l:state.highlights.selected_accent =
          \ wilder#hl_with_attr(
          \ 'WilderPopupMenuSelectedAccent',
          \ l:state.highlights['selected'],
          \ 'underline', 'bold')
  endif

  if has_key(a:opts, 'apply_highlights')
    let l:Apply_highlights = a:opts['apply_highlights']
    if type(l:Apply_highlights) isnot v:t_list
      let l:state.apply_highlights = [l:Apply_highlights]
    else
      let l:state.apply_highlights = l:Apply_highlights
    endif
  else
      let l:state.apply_highlights = []
  endif

  return l:state
endfunction

function! wilder#render#renderer#popupmenu#make(args) abort
  let l:state = s:prepare_state(a:args)

  return {
        \ 'render': {ctx, result -> s:render(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:render(state, ctx, result) abort
  if a:state.run_id != a:ctx.run_id
    let a:state.longest_line_width = 0
    call a:state.draw_cache.clear()
    call a:state.apply_highlights_cache.clear()
  endif

  let a:state.run_id = a:ctx.run_id

  if a:ctx.clear_previous
    let a:state.page = [-1, -1]
  endif

  let l:page = s:make_page(a:state, a:ctx, a:result)
  let a:ctx.page = l:page
  let a:state.page = l:page

  if l:page == [-1, -1]
    call s:close_win(a:state)
    return
  endif

  let a:ctx.highlights = a:state.highlights

  let l:apply_highlights = get(a:state, 'apply_highlights', [])

  let [l:start, l:end] = l:page

  " [[left_columns, chunks, right_columns]]
  let l:raw_lines = []
  " [[chunks_width, total_width]]
  let l:widths = []

  " Draw each line and calculate the width taken by the chunks.
  let l:i = l:start
  while l:i <= l:end
    let l:line = s:draw_line(a:state, a:ctx, a:result, l:i, l:apply_highlights)

    let l:left_width = wilder#render#chunks_displaywidth(l:line[0])
    let l:chunks_width = wilder#render#chunks_displaywidth(l:line[1])
    let l:right_width = wilder#render#chunks_displaywidth(l:line[2])

    let l:total_width = l:left_width + l:chunks_width + l:right_width

    " Store the longest line width seen so far.
    if l:total_width > a:state.longest_line_width
      let a:state.longest_line_width = l:total_width
    endif

    call add(l:raw_lines, l:line)
    call add(l:widths, [l:chunks_width, l:total_width])

    let l:i += 1
  endwhile

  let l:max_width = a:state.get_max_width()
  let l:min_width = a:state.get_min_width()

  " Try to fit the longest line seen so far, if possible.
  let l:expected_width = min([
        \ l:max_width,
        \ &columns - 1,
        \ a:state.longest_line_width,
        \ ])
  if l:expected_width < l:min_width
    let l:expected_width = l:min_width
  endif

  " lines is the list of list of chunks which will be drawn.
  " Each element represents one line of the popupmenu.
  let l:lines = []

  let l:i = 0
  while l:i < len(l:raw_lines)
    let [l:left_column, l:chunks, l:right_column] = l:raw_lines[l:i]
    let [l:chunks_width, l:total_width] = l:widths[l:i]

    let l:is_selected = a:ctx.selected == l:i + l:start

    " Truncate or pad if necessary
    if l:total_width > l:expected_width
      let l:ellipsis = a:state.ellipsis
      let l:ellipsis_width = strdisplaywidth(l:ellipsis)

      let l:to_truncate = l:total_width - l:expected_width + l:ellipsis_width

      let l:chunks_width -= l:to_truncate
      let l:chunks = wilder#render#truncate_chunks(l:chunks_width, l:chunks)

      call add(l:chunks, [l:ellipsis, a:ctx.highlights[l:is_selected ? 'selected' : 'default']])
    elseif l:total_width < l:expected_width
      let l:to_pad = l:expected_width - l:total_width

      call add(l:chunks, [repeat(' ', l:to_pad), a:ctx.highlights[l:is_selected ? 'selected' : 'default']])
    endif

    call add(l:lines, l:left_column + l:chunks + l:right_column)

    let l:i += 1
  endwhile

  " +1 to account for the cmdline prompt.
  " -1 to shift left by 1 column for the added padding.
  let l:pos = get(a:result, 'pos', 0)

  let l:in_sandbox = 0
  try
    call nvim_buf_set_lines(a:state.buf, 0, -1, v:true, [])
  catch /E523/
    " might be in sandbox due to expr mapping
    let l:in_sandbox = 1
  endtry

  if l:in_sandbox
    call timer_start(0, {-> s:render_lines(a:state, l:lines, l:expected_width, l:pos)})
  else
    call s:render_lines(a:state, l:lines, l:expected_width, l:pos)
  endif
endfunction

function! s:render_lines(state, lines, width, pos) abort
  if a:state.win == -1
    call s:open_win(a:state)
  endif

  let [l:start, l:end] = a:state.page

  let l:height = l:end - l:start + 1

  let l:col = a:pos % &columns

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

  let l:row = &lines - l:cmdheight - l:height

  call nvim_win_set_config(a:state.win, {
        \ 'relative': 'editor',
        \ 'row': l:row,
        \ 'col': l:col,
        \ 'height': l:height,
        \ 'width': a:width,
        \ })

  call nvim_buf_clear_namespace(a:state.buf, a:state.ns_id, 0, -1)

  let l:i = 0
  while l:i < len(a:lines)
    let l:chunks = a:lines[l:i]

    let l:text = ''
    for l:chunk in l:chunks
      let l:text .= l:chunk[0]
    endfor

    call nvim_buf_set_lines(a:state.buf, l:i, l:i, v:true, [l:text])

    let l:start = 0
    for l:chunk in l:chunks
      let l:end = l:start + len(l:chunk[0])

      let l:hl = get(l:chunk, 1, a:state.highlights['default'])

      call nvim_buf_add_highlight(a:state.buf, a:state.ns_id, l:hl, l:i, l:start, l:end)

      let l:start = l:end
    endfor

    let l:i += 1
  endwhile

  redraw
endfunction

function! s:pre_hook(state, ctx) abort
  if a:state.buf == -1
    let a:state.buf = nvim_create_buf(v:false, v:true)
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

function! s:make_page(state, ctx, result) abort
  if empty(a:result.value)
    return [-1, -1]
  endif

  let l:page = a:state.page
  let l:selected = a:ctx.selected
  " Adjust -1 (unselected) to show the top of the list.
  let l:selected = l:selected == -1 ? 0 : l:selected

  if l:page != [-1, -1]
    " Selected is within current page, reuse the page.
    if l:selected != -1 && l:selected >= l:page[0] && l:selected <= l:page[1]
      return l:page
    endif

    " Scroll the page forward.
    if a:ctx.direction >= 0 && l:page[1] < l:selected
      " calculate distance moved.
      let l:moved = l:selected - l:page[1]
      return [l:page[0] + l:moved, l:selected]
    endif

    " Scroll the page backward.
    if a:ctx.direction < 0 && l:page[0] > l:selected
      " calculate distance moved.
      let l:moved = l:page[0] - l:selected
      return [l:selected, l:page[1] - l:moved]
    endif
  endif

  " Otherwise make a new page.

  " Assume the worst case scenario that the cursor is on the top row of the
  " cmdline.
  let l:max_height = a:state.get_max_height()
  let l:max_height = min([l:max_height, &lines - &cmdheight]) - 1

  " Page starts at selected.
  if a:ctx.direction >= 0
    let l:start = l:selected

    " Try to include all candidates after selected.
    let l:height = len(a:result.value) - l:selected - 1

    if l:height > l:max_height
      let l:height = l:max_height
    endif

    return [l:start, l:start + l:height]
  endif

  " Page ends at selected.
  let l:end = l:selected

  " Try to include all candidates before selected.
  let l:height = l:selected - 1

  if l:height > l:max_height
    let l:height = l:max_height
  endif

  return [l:end - l:height, l:end]
endfunction

function! s:draw_x(state, ctx, result, i) abort
  let l:use_cache = a:ctx.selected == a:i
  if l:use_cache && a:state.draw_cache.has_key(a:i)
    return a:state.draw_cache.get(a:i)
  endif

  let l:x = wilder#render#draw_x(a:ctx, a:result, a:i)

  if l:use_cache
    call a:state.draw_cache.set(a:i, l:x)
  endif

  return l:x
endfunction

function! s:draw_column(column, ctx, result, i) abort
  let l:is_selected = a:ctx.selected == a:i
  let l:Column = a:column

  if type(l:Column) is v:t_dict
    let l:Column = l:Column.value
  endif

  if type(l:Column) is v:t_string
    return [[l:Column, a:ctx.highlights[l:is_selected ? 'selected' : 'default']]]
  endif

  let l:result = l:Column(a:ctx, a:result, a:i)

  if type(l:result) is v:t_list
    return l:result
  endif

  return [[l:result, a:ctx.highlights[l:is_selected ? 'selected' : 'default']]]
endfunction

" Returns [left_column, chunks, right_column]
function! s:draw_line(state, ctx, result, i, apply_highlights) abort
  let l:is_selected = a:ctx.selected == a:i

  " Add 1 column of padding.
  let l:left_chunks = [[' ', a:ctx.highlights[l:is_selected ? 'selected' : 'default']]]
  for l:Column in a:state.left
    let l:left_chunks += s:draw_column(l:Column, a:ctx, a:result, a:i)
  endfor

  let l:right_chunks = []
  for l:Column in a:state.right
    let l:right_chunks += s:draw_column(l:Column, a:ctx, a:result, a:i)
  endfor

  let l:chunks = s:draw_line_chunks(
        \ a:state, a:ctx, a:result, a:i, a:apply_highlights)

  return [l:left_chunks, l:chunks, l:right_chunks]
endfunction

function! s:draw_line_chunks(state, ctx, result, i, apply_highlights) abort
  let l:is_selected = a:ctx.selected == a:i

  let l:str = s:draw_x(a:state, a:ctx, a:result, a:i)

  if !empty(a:apply_highlights)
    if a:state.apply_highlights_cache.has_key(l:str)
      let l:spans = a:state.apply_highlights_cache.get(l:str)
    else
      let l:data = get(a:result, 'data', {})
      let l:spans = wilder#render#apply_highlights(a:apply_highlights, l:data, l:str)

      if l:spans isnot 0
        call a:state.apply_highlights_cache.set(l:str, l:spans)
      else
        return [[l:str, a:ctx.highlights[l:is_selected ? 'selected' : 'default']]]
      endif
    endif

    return wilder#render#spans_to_chunks(
          \ l:str,
          \ l:spans,
          \ a:ctx.highlights[l:is_selected ? 'selected' : 'default'],
          \ a:ctx.highlights[l:is_selected ? 'selected_accent' : 'accent'])
  endif

  return [[l:str, a:ctx.highlights[l:is_selected ? 'selected' : 'default']]]
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
  call nvim_win_set_option(l:win, 'winhighlight', 'Normal:Normal,Search:None,IncSearch:None')

  let a:state.win = l:win
endfunction
