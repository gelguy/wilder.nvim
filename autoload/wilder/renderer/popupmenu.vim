function! wilder#renderer#popupmenu#(opts) abort
  let l:highlights = copy(get(a:opts, 'highlights', {}))
  let l:state = {
        \ 'highlights': extend(l:highlights, {
        \   'default': get(a:opts, 'hl', 'Pmenu'),
        \   'selected': get(a:opts, 'selected_hl', 'PmenuSel'),
        \   'error': get(a:opts, 'error_hl', 'ErrorMsg'),
        \   'empty_message': get(a:opts, 'empty_message_hl', 'WarningMsg'),
        \ }, 'keep'),
        \ 'ellipsis': wilder#render#to_printable(get(a:opts, 'ellipsis', '...')),
        \ 'apply_incsearch_fix': get(a:opts, 'apply_incsearch_fix', has('nvim')),
        \ 'reverse': get(a:opts, 'reverse', 0),
        \ 'highlight_mode': get(a:opts, 'highlight_mode', 'detailed'),
        \ 'left_offset': get(a:opts, 'left_offset', 1),
        \ 'winblend': get(a:opts, 'winblend', 0),
        \ 'top': get(a:opts, 'top', []),
        \ 'bottom': get(a:opts, 'bottom', []),
        \ 'empty_message': get(a:opts, 'empty_message', 0),
        \
        \ 'page': [-1, -1],
        \ 'buf': -1,
        \ 'win': -1,
        \ 'draw_cache': wilder#cache#cache(),
        \ 'highlight_cache': wilder#cache#cache(),
        \ 'run_id': -1,
        \ 'longest_line_width': 0,
        \ 'render_id': -1,
        \ 'active': 0,
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

  let l:min_width = get(a:opts, 'min_width', 16)
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
    let l:state.left = [' ']
    let l:state.right = [' ', wilder#popupmenu_scrollbar()]
  else
    let l:state.left = get(a:opts, 'left', [])
    let l:state.right = get(a:opts, 'right', [])
  endif

  let l:state.dynamic = s:has_dynamic_component(l:state)

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

  if !has_key(l:state.highlights, 'empty_message')
    let l:state.highlights.empty_message = 'WarningMsg'
  endif

  if has_key(a:opts, 'highlighter')
    let l:Highlighter = a:opts['highlighter']
  elseif has_key(a:opts, 'apply_highlights')
    let l:Highlighter = a:opts['apply_highlights']
  else
    let l:Highlighter = 0
  endif

  if type(l:Highlighter) is v:t_list
    let l:Highlighter = wilder#highlighter#apply_first(l:Highlighter)
  endif

  let l:state.highlighter = l:Highlighter

  if a:opts.mode ==# 'float'
    let l:state.api = wilder#renderer#nvim_api#()
  else
    let l:state.api = wilder#renderer#vim_api#()
  endif

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
    call a:state.highlight_cache.clear()
  endif

  let a:state.run_id = a:ctx.run_id

  if a:ctx.clear_previous
    let a:state.page = [-1, -1]
  endif

  if a:state.page != [-1, -1]
    if a:state.page[0] > len(a:result.value)
      let a:state.page = [-1, -1]
    elseif a:state.page[1] > len(a:result.value)
      let a:state.page[1] = len(a:result.value) - 1
    endif
  endif

  let l:page = s:make_page(a:state, a:ctx, a:result)
  let a:ctx.page = l:page
  let a:state.page = l:page

  let a:ctx.highlights = a:state.highlights

  if a:state.page == [-1, -1] &&
        \ !has_key(a:ctx, 'error') &&
        \ a:state.empty_message is 0
    call a:state.api.hide()
    return
  endif

  let l:need_timer = a:state.api.need_timer()

  if has_key(a:ctx, 'error')
    if l:need_timer
      call timer_start(0, {-> s:draw_error(a:state, a:ctx)})
    else
      call s:draw_error(a:state, a:ctx)
    endif
    return
  endif

  if !a:ctx.done &&
        \ !a:state.dynamic &&
        \ a:state.empty_message is 0
    return
  endif

  let a:state.render_id += 1

  if a:state.api.need_timer()
    let l:render_id = a:state.render_id
    call timer_start(0, {-> s:render_lines_from_timer(l:render_id, a:state, a:ctx, a:result)})
  else
    call s:render_lines(a:state, a:ctx, a:result)
  endif
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

  let l:max_height -= len(a:state.top)
  let l:max_height -= len(a:state.bottom)

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

function! s:render_lines_from_timer(render_id, state, ctx, result)
  " Multiple renders might be queued, skip if there is a newer render
  if a:render_id != a:state.render_id ||
        \ !a:state.active
    return
  endif

  call s:render_lines(a:state, a:ctx, a:result)
endfunction

function! s:render_lines(state, ctx, result) abort
  " +1 to account for the cmdline prompt.
  let l:pos = get(a:result, 'pos', 0) + 1
  let l:pos -= a:state.left_offset
  if l:pos < 0
    let l:pos = 0
  endif

  let l:selected = a:ctx.selected
  let l:reverse = a:state.reverse

  let [l:page_start, l:page_end] = a:state.page

  if a:state.page != [-1, -1]
    let [l:lines, l:width] = s:make_lines(a:state, a:ctx, a:result)
    let l:lines = l:reverse ? reverse(l:lines) : l:lines
    let l:height = l:page_end - l:page_start + 1
  else
    " Handle empty message.
    let l:ctx = copy(a:ctx)
    let l:min_width = a:state.get_min_width()
    let l:max_width = a:state.get_max_width()
    let l:ctx.min_width = l:min_width
    let l:ctx.max_width = l:max_width

    let l:Empty_message = a:state.empty_message
    if type(l:Empty_message) is v:t_dict
      let l:Empty_message = l:Empty_message.value(l:ctx)
    endif

    if type(l:Empty_message) is v:t_func
      let l:Empty_message = l:Empty_message(l:ctx)
    endif

    if type(l:Empty_message) is v:t_string
      let l:hl = get(a:ctx.highlights, 'empty_message', 'WarningMsg')
      let l:Empty_message = s:make_empty_message_from_string(l:Empty_message, l:min_width, l:max_width, l:hl)
    endif

    let l:lines = [l:Empty_message]
    let l:width = wilder#render#chunks_displaywidth(l:Empty_message)
  endif

  let l:ctx = extend({'width': l:width}, a:ctx)

  let l:top_lines = []
  for l:Top in a:state.top
    let l:line = s:get_top_or_bottom_line(l:Top, l:ctx, a:result)

    if empty(l:line)
      continue
    endif

    call add(l:top_lines, l:line)
  endfor
  let l:lines = l:top_lines + l:lines

  for l:Bottom in a:state.bottom
    let l:line = s:get_top_or_bottom_line(l:Bottom, l:ctx, a:result)

    if empty(l:line)
      continue
    endif

    call add(l:lines, l:line)
  endfor

  call a:state.api.show()

  let l:col = l:pos % &columns

  if !has('nvim')
    if l:col + l:width > &columns
      let l:col = &columns - l:width
    endif
    if l:col < 0
      let l:col = 0
    endif
  endif

  let l:cmdheight = wilder#renderer#get_cmdheight()
  let l:height = len(l:lines)
  let l:row = &lines - l:cmdheight - l:height

  let l:top_len = len(l:top_lines)

  call a:state.api.move(l:row, l:col, l:height, l:width)
  call a:state.api.set_option('wrap', v:false)
  call a:state.api.clear_all_highlights()
  call a:state.api.delete_all_lines()

  let l:default_hl = a:state.highlights['default']
  let l:selected_hl = a:state.highlights['selected']

  let l:i = 0
  while l:i < len(l:lines)
    let l:chunks = l:lines[l:i]

    let l:text = ''
    for l:chunk in l:chunks
      let l:text .= l:chunk[0]
    endfor

    call a:state.api.set_line(l:i, l:text)

    " Don't apply selected for top lines or empty message.
    if l:i < l:top_len || l:page_start == -1
      let l:is_selected = 0
    else
      let l:is_selected = l:reverse ? 
            \ l:page_start + (l:height - l:i - l:top_len - 1) == l:selected :
            \ l:page_start + l:i - l:top_len == l:selected
    endif

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
        call a:state.api.add_highlight(l:hl, l:i, l:start, l:end)
      endif

      let l:start = l:end
    endfor

    let l:i += 1
  endwhile

  call a:state.api.set_firstline(1)
  call wilder#renderer#redraw(a:state.apply_incsearch_fix)
endfunction

function! s:get_error_dimensions(state, error)
  let l:width = strdisplaywidth(a:error)
  let l:height = 1

  let l:max_width = a:state.get_max_width()
  if l:width > l:max_width
    let l:height = float2nr(ceil(1.0 * l:width / l:max_width))
    let l:width = l:max_width
  endif

  let l:max_height = a:state.get_max_height()
  if l:height > l:max_height
    let l:height = l:max_height
  endif

  return [l:height, l:width]
endfunction

function! s:make_lines(state, ctx, result) abort
  let l:Highlighter = get(a:state, 'highlighter', [])

  let [l:start, l:end] = a:state.page
  let l:height = l:end - l:start + 1

  let l:left_column_chunks = map(repeat([0], l:height), {-> []})
  call s:draw_columns(l:left_column_chunks, a:state.left, a:ctx, a:result, l:height)

  let l:right_column_chunks = map(repeat([0], l:height), {-> []})
  call s:draw_columns(l:right_column_chunks, a:state.right, a:ctx, a:result, l:height)

  " [[left_column, chunks, right_column]]
  let l:raw_lines = repeat([0], l:height)
  " [[chunks_width, total_width]]
  let l:widths = repeat([0], l:height)

  " Draw each line and calculate the width taken by the chunks.
  let l:i = l:start
  while l:i <= l:end
    let l:line = s:draw_line(a:state, a:ctx, a:result, l:i)
    let l:left_column = l:left_column_chunks[l:i - l:start]
    let l:right_column = l:right_column_chunks[l:i - l:start]

    let l:left_width = wilder#render#chunks_displaywidth(l:left_column)
    let l:chunks_width = wilder#render#chunks_displaywidth(l:line)
    let l:right_width = wilder#render#chunks_displaywidth(l:right_column)

    let l:total_width = l:left_width + l:chunks_width + l:right_width

    " Store the longest line width seen so far.
    if l:total_width > a:state.longest_line_width
      let a:state.longest_line_width = l:total_width
    endif

    let l:index = l:i - l:start
    let l:raw_lines[l:index] = [l:left_column, l:line, l:right_column]
    let l:widths[l:index] = [l:chunks_width, l:total_width]

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
  let l:lines = repeat([0], l:height)

  let l:i = 0
  while l:i < len(l:raw_lines)
    let [l:left_column, l:chunks, l:right_column] = l:raw_lines[l:i]
    let [l:chunks_width, l:total_width] = l:widths[l:i]

    " Truncate or pad if necessary
    if l:total_width > l:expected_width
      let l:ellipsis = a:state.ellipsis
      let l:ellipsis_width = strdisplaywidth(l:ellipsis)

      let l:to_truncate = l:total_width - l:expected_width + l:ellipsis_width

      let l:chunks_width -= l:to_truncate
      let l:chunks = wilder#render#truncate_chunks(l:chunks_width, l:chunks)

      call add(l:chunks, [l:ellipsis])
      call add(l:chunks, [repeat(' ', l:chunks_width - wilder#render#chunks_displaywidth(l:chunks))])
    elseif l:total_width < l:expected_width
      let l:to_pad = l:expected_width - l:total_width

      " l:chunks might point to the cached version
      let l:chunks = copy(l:chunks)
      call add(l:chunks, [repeat(' ', l:to_pad)])
    endif

    let l:lines[l:i] = l:left_column + l:chunks + l:right_column

    let l:i += 1
  endwhile

  return [l:lines, l:expected_width]
endfunction

function! s:draw_columns(column_chunks, columns, ctx, result, height) abort
  for l:Column in a:columns
    let l:column = s:draw_column(l:Column, a:ctx, a:result, a:height)

    if empty(l:column)
      continue
    endif

    let l:i = 0
    while l:i < a:height
      let a:column_chunks[l:i] += l:column[l:i]

      let l:i += 1
    endwhile
  endfor
endfunction

function! s:draw_column(column, ctx, result, height) abort
  let l:Column = a:column

  if type(l:Column) is v:t_dict
    let l:Column = l:Column.value
  endif

  if type(l:Column) is v:t_list
    return repeat([[l:Column]], a:height)
  endif

  if type(l:Column) is v:t_string
    return repeat([[[l:Column]]], a:height)
  endif

  let l:result = l:Column(a:ctx, a:result)

  if type(l:result) is v:t_list
    return l:result
  endif

  return repeat([[[l:result]]], a:height)
endfunction

function! s:draw_line(state, ctx, result, i) abort
  let l:is_selected = a:ctx.selected == a:i

  let l:str = s:draw_x(a:state, a:ctx, a:result, a:i)

  let l:Highlighter = a:state.highlighter

  if l:Highlighter is 0
    return [[l:str]]
  endif

  if !l:is_selected &&
        \ a:state.highlight_cache.has_key(l:str)
    return a:state.highlight_cache.get(l:str)
  endif

  let l:data = get(a:result, 'data', {})
  let l:spans = l:Highlighter(a:ctx, l:str, l:data)

  if l:spans is 0
    return [[l:str]]
  endif

  if a:state.highlight_mode ==# 'basic'
    let l:spans = s:merge_spans(l:spans)
  endif

  let l:chunks = wilder#render#spans_to_chunks(
        \ l:str,
        \ l:spans,
        \ l:is_selected,
        \ a:ctx.highlights)

  if !l:is_selected
    call a:state.highlight_cache.set(l:str, l:chunks)
  endif

  return l:chunks
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

function! s:merge_spans(spans) abort
  if empty(a:spans)
    return []
  endif

  let l:start_byte = a:spans[0][0]
  let l:end_byte = a:spans[-1][0] + a:spans[-1][1]

  return [[l:start_byte, l:end_byte - l:start_byte]]
endfunction

function! s:has_dynamic_component(state) abort
  for l:Component in [a:state.empty_message] +
        \ a:state.left + a:state.right + a:state.top + a:state.bottom
    if type(l:Component) is v:t_dict &&
          \ has_key(l:Component, 'dynamic') &&
          \ l:Component['dynamic']
      return 1
    endif
  endfor

  return 0
endfunction

function! s:pre_hook(state, ctx) abort
  call a:state.api.new({
        \ 'normal_highlight': a:state.highlights.default,
        \ 'winblend': get(a:state, 'winblend', 0)
        \ })

  for l:Component in [a:state.empty_message] +
        \ a:state.left + a:state.right + a:state.top + a:state.bottom
    if type(l:Component) is v:t_dict &&
          \ has_key(l:Component, 'pre_hook')
      call l:Component['pre_hook'](a:ctx)
    endif
  endfor

  let a:state.active = 1
endfunction

function! s:post_hook(state, ctx) abort
  call a:state.api.hide()

  for l:Component in [a:state.empty_message] +
        \ a:state.left + a:state.right + a:state.top + a:state.bottom
    if type(l:Component) is v:t_dict &&
          \ has_key(l:Component, 'post_hook')
      call l:Component['post_hook'](a:ctx)
    endif
  endfor

  let a:state.active = 0
endfunction

function! s:draw_error(state, ctx) abort
  call a:state.api.show()

  let l:error = wilder#render#to_printable(a:ctx.error)
  let [l:height, l:width] = s:get_error_dimensions(a:state, l:error)

  let l:cmdheight = wilder#renderer#get_cmdheight()
  let l:row = &lines - l:cmdheight - l:height

  call a:state.api.move(l:row, 0, l:height, l:width)
  call a:state.api.set_option('wrap', v:true)
  call a:state.api.clear_all_highlights()
  call a:state.api.delete_all_lines()

  let l:hl = a:ctx.highlights['error']

  call a:state.api.set_line(0, l:error)
  call a:state.api.add_highlight(l:hl, 0, 0, len(l:error))

  redraw
endfunction

function! s:make_empty_message_from_string(message, min_width, max_width, hl) abort
  let l:message = a:message
  let l:width = strdisplaywidth(l:message)

  if l:width > a:max_width
    let l:message = wilder#render#truncate_and_pad(a:max_width, l:message)
  elseif l:width < a:min_width
    let l:message .= repeat(' ', a:min_width - l:width)
  endif

  return [[l:message,  a:hl]]
endfunction

function! s:get_top_or_bottom_line(line, ctx, result) abort
  let l:width = a:ctx.width

  let l:Line = a:line
  if type(l:Line) is v:t_dict
    let l:Line = l:Line.value
  endif

  if type(l:Line) is v:t_func
    let l:Line = l:Line(a:ctx, a:result)
  endif

  if type(l:Line) is v:t_string
    if empty(a:line)
      return ''
    endif

    let l:Line = [[wilder#render#truncate_and_pad(a:ctx.width, l:Line)]]
  endif

  if empty(l:Line)
    return []
  endif

  return l:Line
endfunction

function! s:iterate_column(f) abort
  return {ctx, result -> s:iterate_column(a:f, ctx, result)}
endfunction

function! s:iterate_column(f, ctx, result)
  let [l:start, l:end] = a:ctx.page
  let l:data = get(a:result, 'data', v:null)

  let l:lines = repeat([0], l:end - l:start + 1)

  let l:i = l:start
  while l:i <= l:end
    let l:index = l:i - l:start

    let l:x = a:result.value[l:i]
    let l:line = a:f(a:ctx, l:x, l:data)

    if l:line is v:false
      return []
    endif

    let l:lines[l:index] = l:line

    let l:i += 1
  endwhile

  return l:lines
endfunction
