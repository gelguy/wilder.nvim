function! wilder#renderer#popupmenu_border_theme#(opts) abort
  let l:border_chars = get(a:opts, 'border', 'single')
  if type(l:border_chars) is v:t_string
    if l:border_chars ==# 'solid'
      let l:border_chars = [' ', ' ', ' ',
            \               ' ',      ' ',
            \               ' ', ' ', ' ']
    elseif l:border_chars ==# 'rounded'
      let l:border_chars = ['╭', '─', '╮',
            \               '│',      '│',
            \               '╰', '─', '╯']
    elseif l:border_chars ==# 'double'
      let l:border_chars = ['╔', '═', '╗',
            \               '║',      '║',
            \               '╚', '═', '╝']
    else
      " single
      let l:border_chars = ['┌', '─', '┐',
            \               '│',      '│',
            \               '└', '─', '┘']
    endif
  endif

  let l:with_border = copy(a:opts)

  if !has_key(a:opts, 'highlights')
    let l:with_border.highlights = {}
  endif

  let l:top = get(a:opts, 'top', [])
  let l:with_border.top = s:wrap_top_or_bottom(1, l:top, l:border_chars)

  let l:bottom = get(a:opts, 'bottom', [])
  let l:with_border.bottom = s:wrap_top_or_bottom(0, l:bottom, l:border_chars)

  if has_key(a:opts, 'empty_message') &&
        \ (!empty(l:border_chars[3]) || !empty(l:border_chars[4]))
    if type(a:opts.empty_message) is v:t_dict
      let l:with_border.empty_message = copy(a:opts.empty_message)
      let l:Value = a:opts.empty_message.value
      let l:with_border.empty_message.value = {ctx -> s:wrap_empty_message(ctx, l:Value, l:border_chars)}
    else
      let l:with_border.empty_message = {ctx -> s:wrap_empty_message(ctx, a:opts.empty_message, l:border_chars)}
    endif
  endif

  if !has_key(a:opts, 'left') && !has_key(a:opts, 'right')
    let l:with_border.left = [' ']
    let l:with_border.right = [' ', wilder#popupmenu_scrollbar()]
  else
    let l:with_border.left = copy(get(a:opts, 'left', []))
    let l:with_border.right = copy(get(a:opts, 'right', []))
  endif

  if !has_key(l:with_border.highlights, 'border')
    let l:with_border.highlights.border = 'Normal'
  endif

  if !has_key(l:with_border.highlights, 'bottom_border')
    let l:with_border.highlights.bottom_border = l:with_border.highlights.border
  endif

  let l:border_hl = l:with_border.highlights.border

  if !empty(l:border_chars[3])
    call insert(l:with_border.left, [l:border_chars[3], l:border_hl])
  endif
  if !empty(l:border_chars[4])
    call add(l:with_border.right, [l:border_chars[4], l:border_hl])
  endif

  return l:with_border
endfunction

function! s:wrap_top_or_bottom(is_top, lines, border_chars) abort
  let l:new_lines = []
  for l:Line in a:lines
    let l:New_line = s:wrap_with_border(l:Line, a:border_chars[3], a:border_chars[4])
    call add(l:new_lines, l:New_line)
  endfor

  if a:is_top
    if !empty(a:border_chars[0]) || !empty(a:border_chars[1]) || !empty(a:border_chars[2])
      call insert(l:new_lines, {ctx -> s:make_top_or_bottom_border(ctx, 1, a:border_chars)})
    endif
  elseif !empty(a:border_chars[5]) || !empty(a:border_chars[6]) || !empty(a:border_chars[7])
    call add(l:new_lines, {ctx -> s:make_top_or_bottom_border(ctx, 0, a:border_chars)})
  endif

  return l:new_lines
endfunction

function! s:wrap_with_border(line, left, right) abort
  if type(a:line) is v:t_dict
    return s:wrap_dict_with_border(a:line, a:left, a:right)
  endif

  return {ctx, result -> s:wrap_string_or_func_with_border(ctx, result, a:line, a:left, a:right)}
endfunction

function! s:wrap_dict_with_border(line, left, right) abort
  let l:Value = a:line.value
  let l:line = copy(a:line)
  let l:line.value = {ctx, result -> s:wrap_string_or_func_with_border(ctx, result, l:Value, a:left, a:right)}
  return l:line
endfunction

function! s:wrap_string_or_func_with_border(ctx, result, line, left, right) abort
  let l:width = a:ctx.width
  let l:width -= strdisplaywidth(a:left)
  let l:width -= strdisplaywidth(a:right)
  if l:width < 0
    let l:width = 0
  endif

  if type(a:line) is v:t_func
    let l:ctx = copy(a:ctx)
    let l:ctx.width = l:width
    let l:result = a:line(l:ctx, a:result)

    if empty(l:result)
      return []
    endif

    if type(l:result) is v:t_string
      let l:chunks = [[wilder#render#truncate_and_pad(l:width, l:result)]]
    else
      let l:chunks = l:result
    endif
  else
    if empty(a:line)
      return ''
    endif

    let l:chunks = [[wilder#render#truncate_and_pad(l:width, a:line)]]
  endif

  let l:border_hl = a:ctx.highlights.border
  return [[a:left, l:border_hl]] + l:chunks + [[a:right, l:border_hl]]
endfunction

function! s:make_top_or_bottom_border(ctx, is_top, border_chars) abort
  let l:left = a:is_top ? a:border_chars[0] : a:border_chars[5]
  let l:middle = a:is_top ? a:border_chars[1] : a:border_chars[6]
  let l:right = a:is_top ? a:border_chars[2] : a:border_chars[7]

  let l:left_width = strdisplaywidth(l:left)
  let l:middle_width = strdisplaywidth(l:middle)
  let l:right_width = strdisplaywidth(l:right)

  let l:expected_middle_width = a:ctx.width - l:left_width - l:right_width
  let l:middle_repeat =  l:expected_middle_width / l:middle_width
  if l:middle_repeat < 0
    let l:middle_repeat = 0
  endif

  let l:middle_str = repeat(l:middle, l:middle_repeat)
  let l:actual_middle_width = strdisplaywidth(l:middle_str)
  if l:actual_middle_width < l:expected_middle_width
    let l:middle_chars = split(l:middle, '\zs')

    let l:i = 0
    for l:char in l:middle_chars
      let l:new_middle_width = l:actual_middle_width + strdisplaywidth(l:char)

      if l:new_middle_width > l:expected_middle_width
        break
      endif

      let l:middle_str .= l:char
      let l:actual_middle_width = l:new_middle_width
    endfor

    let l:middle_str .= repeat(' ', l:expected_middle_width - l:actual_middle_width)
  endif

  let l:border_hl = a:ctx.highlights.border
  let l:middle_hl = a:is_top ? l:border_hl : a:ctx.highlights.bottom_border

  return [[l:left, l:border_hl], [l:middle_str, l:middle_hl], [l:right, l:border_hl]]
endfunction

function! s:wrap_empty_message(ctx, message, border_chars) abort
  let l:left = a:border_chars[3]
  let l:right = a:border_chars[4]
  let l:left_width = strdisplaywidth(l:left)
  let l:right_width = strdisplaywidth(l:right)

  let l:min_width = a:ctx.min_width - l:left_width - l:right_width
  let l:max_width = a:ctx.max_width - l:left_width - l:right_width

  if type(a:message) is v:t_string
    let l:message_str = a:message
    let l:width = strdisplaywidth(l:message_str)

    if l:width > l:max_width
      let l:message_str = wilder#render#truncate_and_pad(l:max_width, l:message_str)
    elseif l:width < l:min_width
      let l:message_str .= repeat(' ', l:min_width - l:width)
    endif

    let l:empty_message_hl = get(a:ctx.highlights, 'empty_message', 'WarningMsg')
    let l:chunks = [[l:message_str, l:empty_message_hl]]
  else
    let l:ctx = copy(a:ctx)
    let l:ctx.min_width = l:min_width
    let l:ctx.max_width = l:max_width

    let l:chunks = a:message(l:ctx)
  endif

  let l:border_hl = a:ctx.highlights.border
  return [[l:left, l:border_hl]] + l:chunks + [[l:right, l:border_hl]]
endfunction
