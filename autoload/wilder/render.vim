scriptencoding utf-8

let s:hl_map = {}
let s:hl_link_map = {}
let s:has_strtrans_issue = strdisplaywidth('') != strdisplaywidth(strtrans(''))

function! wilder#render#component_len(component, ctx, result) abort
  if type(a:component) is v:t_string
    return wilder#render#strdisplaywidth(wilder#render#to_printable(a:component))
  endif

  if type(a:component) is v:t_dict
    if has_key(a:component, 'len')
      if type(a:component.len) is v:t_func
        return a:component.len(a:ctx, a:result)
      else
        return a:component.len
      endif
    endif

    if type(a:component.value) is v:t_func
      let l:Value = a:component.value(a:ctx, a:result)
    else
      let l:Value = a:component.value
    endif

    return wilder#render#component_len(l:Value, a:ctx, a:result)
  endif

  if type(a:component) is v:t_func
    let l:Value = a:component(a:ctx, a:result)

    return wilder#render#component_len(l:Value, a:ctx, a:result)
  endif

  " v:t_list
  let l:len = 0

  for l:Elem in a:component
    let l:len += wilder#render#component_len(l:Elem, a:ctx, a:result)
  endfor

  return l:len
endfunction

function! wilder#render#component_pre_hook(component, ctx) abort
  call s:component_hook(a:component, a:ctx, 'pre')
endfunction

function! wilder#render#component_post_hook(component, ctx) abort
  call s:component_hook(a:component, a:ctx, 'post')
endfunction

function! s:component_hook(component, ctx, key) abort
  if type(a:component) is v:t_dict
    if has_key(a:component, a:key . '_hook')
      call a:component[a:key . '_hook'](a:ctx)
    endif

    call s:component_hook(a:component.value, a:ctx, a:key)
  elseif type(a:component) is v:t_list
    for l:Elem in a:component
      call s:component_hook(l:Elem, a:ctx, a:key)
    endfor
  endif
endfunction

function! wilder#render#make_page(ctx, result) abort
  if empty(a:result.value)
    return [-1, -1]
  endif

  let l:page = a:ctx.page
  let l:selected = a:ctx.selected

  " if selected is within old page
  if l:page != [-1, -1] && l:selected != -1 && l:selected >= l:page[0] && l:selected <= l:page[1]
    " check if page_start to selected still fits within space
    " space might have changed due to resizing or due to custom draw functions
    let l:selected = a:ctx.selected

    let l:i = l:page[0]
    let l:separator_width = strdisplaywidth(a:ctx.separator)
    let l:width = wilder#render#strdisplaywidth(s:draw_x_cached(a:ctx, a:result, l:i))
    let l:i += 1

    while l:i <= l:page[1]
      let l:width += l:separator_width
      let l:width += wilder#render#strdisplaywidth(s:draw_x_cached(a:ctx, a:result, l:i))

      " cannot fit in current page
      if l:width > a:ctx.space
        break
      endif

      let l:i += 1
    endwhile

    if l:width <= a:ctx.space
      return l:page
    endif

    " continue below otherwise
  endif

  let l:selected = l:selected == -1 ? 0 : l:selected

  if l:page == [-1, -1]
    return s:make_page_from_start(a:ctx, a:result, l:selected)
  endif

  if a:ctx.direction < 0
    return s:make_page_from_end(a:ctx, a:result, l:selected)
  endif

  return s:make_page_from_start(a:ctx, a:result, l:selected)
endfunction

function! s:make_page_from_start(ctx, result, start) abort
  let l:space = a:ctx.space
  let l:start = a:start
  let l:end = l:start

  let l:width = wilder#render#strdisplaywidth(s:draw_x_cached(a:ctx, a:result, l:start))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(a:ctx.separator)

  while 1
    if l:end + 1 >= len(a:result.value)
      break
    endif

    let l:width = wilder#render#strdisplaywidth(s:draw_x_cached(a:ctx, a:result, l:end + 1))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! s:make_page_from_end(ctx, result, end) abort
  let l:space = a:ctx.space
  let l:end = a:end
  let l:start = l:end

  let l:width = wilder#render#strdisplaywidth(s:draw_x_cached(a:ctx, a:result, l:start))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(a:ctx.separator)

  while 1
    if l:start - 1 < 0
      break
    endif

    let l:width = wilder#render#strdisplaywidth(s:draw_x_cached(a:ctx, a:result, l:start - 1))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:start -= 1
  endwhile

  " moving left from page [5,10] ends in [0,4]
  " but there might be leftover space, so we increase l:end to fill up the
  " space e.g. to [0,6]
  while 1
    if l:end + 1 >= len(a:result.value)
      break
    endif

    let l:width = wilder#render#strdisplaywidth(s:draw_x_cached(a:ctx, a:result, l:end + 1))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! wilder#render#draw_x(ctx, result, i)
  let l:x = a:result.value[a:i]

  if has_key(a:result, 'draw')
    let l:ctx = {
          \ 'i': a:i,
          \ 'selected': a:ctx.selected == a:i,
          \ }

    for l:F in a:result.draw
      if type(l:F) isnot v:t_func
        let l:F = function(l:F)
      endif

      let l:x = l:F(l:ctx, l:x, get(a:result, 'data', {}))
    endfor
  endif

  return wilder#render#to_printable(l:x)
endfunction

function! wilder#render#make_hl_chunks(left, right, ctx, result) abort
  let l:chunks = []
  let l:chunks += s:draw_component(a:left, a:ctx.highlights['default'], a:ctx, a:result)

  if has_key(a:ctx, 'error')
    let l:chunks += s:draw_error(a:ctx.highlights['error'], a:ctx, a:ctx.error)
  else
    let l:chunks += s:draw_xs(a:ctx, a:result)
  endif

  let l:chunks += s:draw_component(a:right, a:ctx.highlights['default'], a:ctx, a:result)

  return wilder#render#normalise(a:ctx.highlights['default'], l:chunks)
endfunction

function! wilder#render#normalise(hl, chunks) abort
  if empty(a:chunks)
    return []
  endif

  let l:res = []

  let l:text = ''
  let l:hl = a:hl

  for l:chunk in a:chunks
    let l:chunk_hl = get(l:chunk, 1, a:hl)

    if l:chunk_hl ==# l:hl
      let l:text .= l:chunk[0]
    else
      if !empty(l:text)
        call add(l:res, [l:text, l:hl])
      endif

      let l:text = l:chunk[0]
      let l:hl = l:chunk_hl
    endif
  endfor

  call add(l:res, [l:text, l:hl])

  return l:res
endfunction

function! s:draw_xs(ctx, result) abort
  let l:selected = a:ctx.selected
  let l:space = a:ctx.space
  let l:page = a:ctx.page
  let l:separator = a:ctx.separator

  if l:page == [-1, -1]
    return [[repeat(' ', l:space), a:ctx.highlights['default']]]
  endif

  let l:start = l:page[0]
  let l:end = l:page[1]

  " only 1 x, possible that it exceeds l:space
  if l:start == l:end
    let l:x = s:draw_x_cached(a:ctx, a:result, l:start)

    if wilder#render#strdisplaywidth(l:x) > l:space
      let l:ellipsis = a:ctx.ellipsis
      let l:space_minus_ellipsis = l:space - strdisplaywidth(l:ellipsis)

      let l:x = wilder#render#truncate(l:space_minus_ellipsis, l:x)

      let l:res = []
      call s:add_result(a:ctx, l:res, l:x, l:start == l:selected)
      call add(l:res, [l:ellipsis, a:ctx.highlights['default']])
      let l:padding = repeat(' ', l:space - wilder#render#strdisplaywidth(l:x))
      call add(l:res, [l:padding, a:ctx.highlights['default']])
      return l:res
    endif
  endif

  let l:current = l:start
  let l:res = [['']]
  let l:len = 0

  while l:current <= l:end
    if l:current != l:start
      call add(l:res, [l:separator, a:ctx.highlights.separator])
      let l:len += strdisplaywidth(l:separator)
    endif

    let l:x = s:draw_x_cached(a:ctx, a:result, l:current)
    call s:add_result(a:ctx, l:res, l:x, l:current == l:selected)

    let l:len += wilder#render#strdisplaywidth(l:x)
    let l:current += 1
  endwhile

  call add(l:res, [repeat(' ', l:space - l:len)])
  return l:res
endfunction

function! s:add_result(ctx, res, x, selected) abort
  if type(a:x) is v:t_string
    call add(a:res, [a:x, a:ctx.highlights[a:selected ? 'selected' : 'default']])
    return
  endif

  if type(a:x) is v:t_dict
    if a:selected
      let l:hl = get(a:x, 'selected_hl', a:ctx.highlights['selected'])
    else
      let l:hl = get(a:x, 'hl', a:ctx.highlights['default'])
    endif

    if l:hl[0] ==# '@'
      let l:hl = get(a:ctx.highlights, l:hl[1:], a:ctx.highlights[a:selected ? 'selected' : 'default'])
    endif

    call add(a:res, [a:x['value'], l:hl])
    return
  endif

  " v:t_list
  for l:elem in a:x
    call s:add_result(a:ctx, a:res, l:elem, a:selected)
  endfor
endfunction

function! s:draw_error(hl, ctx, error) abort
  let l:space = a:ctx.space
  let l:error = wilder#render#to_printable(a:error)

  if strdisplaywidth(l:error) > a:ctx.space
    let l:ellipsis = wilder#render#to_printable(a:ctx.ellipsis)
    let l:space_minus_ellipsis = l:space - strdisplaywidth(l:ellipsis)

    let l:error = wilder#render#truncate(l:space_minus_ellipsis, l:error)

    let l:error = l:error . l:ellipsis
  endif

  return [[l:error, a:hl], [repeat(' ', l:space - strdisplaywidth(l:error))]]
endfunction

function! s:draw_component(Component, hl, ctx, result) abort
  if type(a:Component) is v:t_string
    return [[wilder#render#to_printable(a:Component), a:hl]]
  endif

  if type(a:Component) is v:t_dict
    if has_key(a:Component, 'hl') && !empty(a:Component.hl)
      let l:hl = a:Component.hl
    else
      let l:hl = a:hl
    endif

    if type(a:Component.value) is v:t_func
      let l:Value = a:Component.value(a:ctx, a:result)
    else
      let l:Value = a:Component.value
    endif

    return s:draw_component(l:Value, l:hl, a:ctx, a:result)
  endif

  if type(a:Component) is v:t_func
    let l:Value = a:Component(a:ctx, a:result)

    return s:draw_component(l:Value, a:hl, a:ctx, a:result)
  endif

  " v:t_list
  let l:res = []

  for l:Elem in a:Component
    let l:res += s:draw_component(l:Elem, a:hl, a:ctx, a:result)
  endfor

  return l:res
endfunction

function! wilder#render#init_hl() abort
  for l:key in keys(s:hl_map)
    exe s:hl_map[l:key]
  endfor
endfunction

function! wilder#render#make_hl(name, args) abort
  let l:type = type(a:args)
  if l:type == v:t_list
    if type(a:args[0]) == v:t_list
      return s:make_hl_from_list_list(a:name, a:args)
    endif

    return s:make_hl_from_dict_list(a:name, a:args)
  else
    return s:make_hl_from_string(a:name, a:args)
  endif
endfunction

function! s:make_hl_from_string(name, args) abort
  let l:cmd = 'hi! link ' . a:name . ' ' . a:args

  let s:hl_map[a:name] = l:cmd
  return a:name
endfunction

function! s:make_hl_from_dict_list(name, args) abort
  let l:term_hl = s:get_attrs_as_list(a:args[0])

  let l:cterm_hl = [
        \ get(a:args[1], 'foreground', 'NONE'),
        \ get(a:args[1], 'background', 'NONE')
        \ ] + s:get_attrs_as_list(a:args[1])

  let l:gui_hl = [
        \ get(a:args[2], 'foreground', 'NONE'),
        \ get(a:args[2], 'background', 'NONE')
        \ ] + s:get_attrs_as_list(a:args[2])

  return s:make_hl_from_list_list(a:name, [l:term_hl, l:cterm_hl, l:gui_hl])
endfunction

function! s:make_hl_from_list_list(name, args) abort
  let l:term_hl = a:args[0]
  let l:cterm_hl = a:args[1]
  let l:gui_hl = a:args[2]

  let l:cmd = 'hi! ' . a:name . ' '

  if len(l:term_hl) > 2
    let l:cmd .= 'term=' . join(l:term_hl[2:], ',') . ' '
  endif

  if len(l:cterm_hl) > 2
    let l:cmd .= 'cterm=' . join(l:cterm_hl[2:], ',') . ' '
  endif

  if len(l:cterm_hl) >= 1
    if l:cterm_hl[0] >= 0
      let l:cmd .= 'ctermfg=' . l:cterm_hl[0] . ' '
    endif

    if len(l:cterm_hl) >= 2 && l:cterm_hl[1] >= 0
      let l:cmd .= 'ctermbg=' . l:cterm_hl[1] . ' '
    endif
  endif

  if len(l:gui_hl) > 2
    let l:cmd .= 'gui=' . join(l:gui_hl[2:], ',') . ' '
  endif

  if len(l:gui_hl) >= 1
    if type(l:gui_hl[0]) == v:t_number
      let l:cmd .= 'guifg=' . printf('#%06x', l:gui_hl[0]) . ' '
    else
      let l:cmd .= 'guifg=' . l:gui_hl[0] . ' '
    endif

    if len(l:gui_hl) >= 2
      if type(l:gui_hl[1]) == v:t_number
        let l:cmd .= 'guibg=' . printf('#%06x', l:gui_hl[1]) . ' '
      else
        let l:cmd .= 'guibg=' . l:gui_hl[1] . ' '
      endif
    endif
  endif

  let s:hl_map[a:name] = l:cmd
  return a:name
endfunction

function! s:get_attrs_as_list(attrs) abort
  let l:res = []

  if get(a:attrs, 'bold', 0)
    call add(l:res, 'bold')
  endif
  if get(a:attrs, 'italic', 0)
    call add(l:res, 'italic')
  endif
  if get(a:attrs, 'reverse', 0)
    call add(l:res, 'reverse')
  endif
  if get(a:attrs, 'standout', 0)
    call add(l:res, 'standout')
  endif
  if get(a:attrs, 'underline', 0)
    call add(l:res, 'underline')
  endif
  if get(a:attrs, 'undercurl', 0)
    call add(l:res, 'undercurl')
  endif

  return l:res
endfunction

function! wilder#render#get_colors(group) abort
  if has('nvim')
    return wilder#render#get_colors_nvim(a:group)
  else
    return wilder#render#get_colors_vim(a:group)
  endif
endfunction

function! wilder#render#get_colors_nvim(group) abort
  try
    let l:cterm_hl = nvim_get_hl_by_name(a:group, 0)
    let l:gui_hl = nvim_get_hl_by_name(a:group, 1)

    return [{}, l:cterm_hl, l:gui_hl]
  catch
    return [{}, {}, {}]
  endtry
endfunction

function! wilder#render#get_colors_vim(group) abort
  try
    redir => l:highlight
    silent execute 'silent highlight ' . a:group
    redir END

    let l:link_matches = matchlist(l:highlight, 'links to \(\S\+\)')
    if len(l:link_matches) > 0 " follow the link
      return wilder#render#get_colors_vim(l:link_matches[1])
    endif

    let l:term_hl = {}
    if match(l:highlight, 'term=\S*') >= 0
      call s:get_hl_attrs(l:term_hl, 'term', l:highlight)
    endif

    let l:cterm_hl = {}
    if match(l:highlight, 'cterm=\S*') >= 0
      call s:get_hl_attrs(l:cterm_hl, 'cterm', l:highlight)
    endif

    let l:cterm_hl.background = get(matchlist(l:highlight, 'ctermbg=\([0-9A-Za-z]\+\)'), 1, 'NONE')
    let l:cterm_hl.foreground = get(matchlist(l:highlight, 'ctermfg=\([0-9A-Za-z]\+\)'), 1, 'NONE')

    let l:gui_hl = {}
    if match(l:highlight, 'gui=\S*') >= 0
      call s:get_hl_attrs(l:gui_hl, 'gui', l:highlight)
    endif

    let l:gui_hl.background = get(matchlist(l:highlight, 'guibg=\([#0-9A-Za-z]\+\)'), 1, 'NONE')
    let l:gui_hl.foreground = get(matchlist(l:highlight, 'guifg=\([#0-9A-Za-z]\+\)'), 1, 'NONE')

    return [l:term_hl, l:cterm_hl, l:gui_hl]
  catch
    return [{}, {}, {}]
  endtry
endfunction

function! s:get_hl_attrs(attrs, key, hl) abort
  let a:attrs.bold = match(a:hl, a:key . '=\S*bold\S*') >= 0
  let a:attrs.italic = match(a:hl, a:key . '=\S*italic\S*') >= 0
  let a:attrs.reverse = match(a:hl, a:key . '=\S*reverse\S*') >= 0
  let a:attrs.standout = match(a:hl, a:key . '=\S*standout\S*') >= 0
  let a:attrs.underline = match(a:hl, a:key . '=\S*underline\S*') >= 0
  let a:attrs.undercurl = match(a:hl, a:key . '=\S*undercurl\S*') >= 0
endfunction

function! s:draw_x_cached(ctx, result, i) abort
  if !has_key(a:ctx, 'draw_cache')
    let a:ctx.draw_cache = {}
  endif

  if has_key(a:ctx.draw_cache, a:i)
    return a:ctx.draw_cache[a:i]
  endif

  let l:x = wilder#render#draw_x(a:ctx, a:result, a:i)

  let a:ctx.draw_cache[a:i] = l:x

  return l:x
endfunction

function! wilder#render#strdisplaywidth(x) abort
  if type(a:x) is v:t_list
    let l:width = 0

    for l:elem in a:x
      let l:width += wilder#render#strdisplaywidth(l:elem)
    endfor

    return l:width
  endif

  if type(a:x) is v:t_dict
    return wilder#render#strdisplaywidth(a:x['value'])
  endif

  return strdisplaywidth(a:x)
endfunction

function! wilder#render#to_printable(x) abort
  if type(a:x) is v:t_list
    return map(a:x, {i, x -> wilder#render#to_printable(x)})
  endif

  if type(a:x) is v:t_dict
    return extend(copy(a:x), {
          \ 'value': wilder#render#to_printable(a:x['value']),
          \ })
  endif

  if !s:has_strtrans_issue
    " check if first character is a combining character
    if strdisplaywidth(' ' . a:x) == strdisplaywidth(a:x)
      return strtrans(' ' . a:x)
    endif

    return strtrans(a:x)
  endif

  let l:transformed = strtrans(a:x)
  " strtrans is ok
  if strdisplaywidth(a:x) == strdisplaywidth(l:transformed)
    " check if first character is a combining character
    if strdisplaywidth(' ' . a:x) == strdisplaywidth(a:x)
      return strtrans(' ' . a:x)
    endif

    return strtrans(a:x)
  endif

  let l:res = ''
  let l:first = 1

  for l:char in split(a:x, '\zs')
    let l:transformed_char = strtrans(l:char)

    let l:transformed_width = strdisplaywidth(l:transformed_char)
    let l:width = strdisplaywidth(l:char)

    if l:transformed_width == l:width
      " strtrans is ok
      let l:res .= l:transformed_char
    elseif l:transformed_width == 0
      " strtrans returns empty character, use original char
      if l:first && strdisplaywidth(' ' . l:char) == strdisplaywidth(l:char)
        " check if first character is combining character
        let l:res .= ' ' . l:char
      else
        let l:res .= l:char
      endif
    else
      " fallback to hex representation
      let l:res .= '<' . printf('%02x', char2nr(l:char)) . '>'
    endif

    let l:first = 0
  endfor

  return l:res
endfunction

function! wilder#render#truncate(len, x) abort
  if type(a:x) is v:t_dict
    return extend(copy(a:x), {
          \ 'value': wilder#render#truncate(a:len, a:x['value']),
          \ })
  endif

  if type(a:x) is v:t_list
    let l:width = 0
    let l:res = []
    let l:i = 0

    while l:i < len(a:x)
      let l:elem = a:x[l:i]
      let l:elem_width = wilder#render#strdisplaywidth(l:elem)

      if l:width + l:elem_width > a:len
        call add(l:res, wilder#render#truncate(l:elem, a:len - l:width))
        return l:res
      endif

      call add(l:res, l:elem)
      let l:width += l:elem_width
      let l:i += 1
    endwhile

    return l:res
  endif

  " v:t_string
  let l:width = strdisplaywidth(a:x)
  let l:chars = split(a:x, '\zs')
  let l:index = len(l:chars) - 1

  while l:width > a:len && l:index >= 0
    let l:width -= strdisplaywidth(l:chars[l:index])

    let l:index -= 1
  endwhile

  return join(l:chars[:l:index], '')
endfunction

let s:high_control_characters = {
      \ '': '^?',
      \ '': '<80>',
      \ '': '<81>',
      \ '': '<82>',
      \ '': '<83>',
      \ '': '<84>',
      \ '': '<85>',
      \ '': '<86>',
      \ '': '<87>',
      \ '': '<88>',
      \ '': '<89>',
      \ '': '<8a>',
      \ '': '<8b>',
      \ '': '<8c>',
      \ '': '<8d>',
      \ '': '<8e>',
      \ '': '<8f>',
      \ '': '<90>',
      \ '': '<91>',
      \ '': '<92>',
      \ '': '<93>',
      \ '': '<94>',
      \ '': '<95>',
      \ '': '<96>',
      \ '': '<97>',
      \ '': '<98>',
      \ '': '<99>',
      \ '': '<9a>',
      \ '': '<9b>',
      \ '': '<9c>',
      \ '': '<9d>',
      \ '': '<9e>',
      \ '': '<9f>',
      \}
