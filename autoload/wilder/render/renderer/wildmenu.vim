function! wilder#render#renderer#wildmenu#prepare_state(args) abort
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
        \ 'buf': -1,
        \ 'win': -1,
        \ 'columns': -1,
        \ 'cmdheight': -1,
        \ 'draw_cache': {},
        \ 'apply_highlights_cache': {},
        \ 'run_id': -1,
        \ }

  if !has_key(a:args, 'left') && !has_key(a:args, 'right')
    let l:state.left = [wilder#previous_arrow()]
    let l:state.right = [wilder#next_arrow()]
  else
    let l:state.left = get(a:args, 'left', [])
    let l:state.right = get(a:args, 'right', [])
  endif

  if !has_key(l:state.highlights, 'separator')
    let l:state.highlights.separator =
          \ get(a:args, 'separator_hl', l:state.highlights['default'])
  endif

  if !has_key(l:state.highlights, 'accent')
    let l:state.highlights.accent =
          \ wilder#hl_with_attr('WilderAccent',
          \   l:state.highlights['default'], 'underline', 'bold')
  endif

  if !has_key(l:state.highlights, 'selected_accent')
    let l:state.highlights.selected_accent =
          \ wilder#hl_with_attr('WilderSelectedAccent', l:state.highlights['selected'],
          \   'underline', 'bold')
  endif

  if has_key(a:args, 'apply_highlights')
    let l:Apply_highlights = a:args['apply_highlights']
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

function! wilder#render#renderer#wildmenu#make_hl_chunks(state, width, ctx, result) abort
  if a:state.run_id != a:ctx.run_id
    let a:state.draw_cache = {}
    let a:state.apply_highlights_cache = {}
  endif

  let a:state.run_id = a:ctx.run_id

  if a:ctx.clear_previous
    let a:state.page = [-1, -1]
  endif

  let l:space_used = wilder#render#renderer#wildmenu#component_len(
        \ a:state.left,
        \ a:ctx,
        \ a:result)

  let l:space_used += wilder#render#renderer#wildmenu#component_len(
        \ a:state.right,
        \ a:ctx,
        \ a:result)

  let a:ctx.space = a:width - l:space_used
  let a:ctx.page = a:state.page
  let a:ctx.separator = a:state.separator
  let a:ctx.ellipsis = a:state.ellipsis

  let l:page = s:make_page(a:state, a:ctx, a:result)
  let a:ctx.page = l:page
  let a:state.page = l:page

  let a:ctx.highlights = a:state.highlights

  return s:make_hl_chunks(a:state, a:ctx, a:result,
        \ get(a:state, 'apply_highlights', []))
endfunction

function! wilder#render#renderer#wildmenu#component_len(component, ctx, result) abort
  if type(a:component) is v:t_string
    return strdisplaywidth(wilder#render#to_printable(a:component))
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

    return wilder#render#renderer#wildmenu#component_len(l:Value, a:ctx, a:result)
  endif

  if type(a:component) is v:t_func
    let l:Value = a:component(a:ctx, a:result)

    return wilder#render#renderer#wildmenu#component_len(l:Value, a:ctx, a:result)
  endif

  " v:t_list
  let l:len = 0

  for l:Elem in a:component
    let l:len += wilder#render#renderer#wildmenu#component_len(l:Elem, a:ctx, a:result)
  endfor

  return l:len
endfunction

function! wilder#render#renderer#wildmenu#component_pre_hook(component, ctx) abort
  call s:component_hook(a:component, a:ctx, 'pre')
endfunction

function! wilder#render#renderer#wildmenu#component_post_hook(component, ctx) abort
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

function! s:make_page(state, ctx, result) abort
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
    let l:width = strdisplaywidth(s:draw_x(a:state, a:ctx, a:result, l:i))
    let l:i += 1

    while l:i <= l:page[1]
      let l:width += l:separator_width
      let l:width += strdisplaywidth(s:draw_x(a:state, a:ctx, a:result, l:i))

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
    return s:make_page_from_start(a:state, a:ctx, a:result, l:selected)
  endif

  if a:ctx.direction < 0
    return s:make_page_from_end(a:state, a:ctx, a:result, l:selected)
  endif

  return s:make_page_from_start(a:state, a:ctx, a:result, l:selected)
endfunction

function! s:draw_x(state, ctx, result, i) abort
  if has_key(a:state.draw_cache, a:i)
    return a:state.draw_cache[a:i]
  endif

  let l:x = wilder#render#draw_x(a:ctx, a:result, a:i)
  let a:state.draw_cache[a:i] = l:x

  return l:x
endfunction

function! s:make_page_from_start(state, ctx, result, start) abort
  let l:space = a:ctx.space
  let l:start = a:start
  let l:end = l:start

  let l:width = strdisplaywidth(s:draw_x(a:state, a:ctx, a:result, l:start))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(a:ctx.separator)

  while 1
    if l:end + 1 >= len(a:result.value)
      break
    endif

    let l:width = strdisplaywidth(s:draw_x(a:state, a:ctx, a:result, l:end + 1))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! s:make_page_from_end(state, ctx, result, end) abort
  let l:space = a:ctx.space
  let l:end = a:end
  let l:start = l:end

  let l:width = strdisplaywidth(s:draw_x(a:state, a:ctx, a:result, l:start))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(a:ctx.separator)

  while 1
    if l:start - 1 < 0
      break
    endif

    let l:width = strdisplaywidth(s:draw_x(a:state, a:ctx, a:result, l:start - 1))

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

    let l:width = strdisplaywidth(s:draw_x(a:state, a:ctx, a:result, l:end + 1))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! s:make_hl_chunks(state, ctx, result, apply_highlights) abort
  let l:chunks = []
  let l:chunks += s:draw_component(a:state.left, a:ctx.highlights['default'], a:ctx, a:result)

  if has_key(a:ctx, 'error')
    let l:chunks += s:draw_error(a:ctx.highlights['error'], a:ctx, a:ctx.error)
  else
    let l:chunks += s:draw_xs(a:state, a:ctx, a:result, a:apply_highlights)
  endif

  let l:chunks += s:draw_component(a:state.right, a:ctx.highlights['default'], a:ctx, a:result)

  return wilder#render#normalise_chunks(a:ctx.highlights['default'], l:chunks)
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

function! s:draw_xs(state, ctx, result, apply_highlights) abort
  let l:selected = a:ctx.selected
  let l:space = a:ctx.space
  let l:page = a:ctx.page
  let l:separator = a:ctx.separator

  if l:page == [-1, -1]
    return [[repeat(' ', l:space), a:ctx.highlights['default']]]
  endif

  let l:start = l:page[0]
  let l:end = l:page[1]

  let l:xs = []
  let l:len = l:end - l:start + 1
  let l:data = type(a:result) is v:t_dict ?
        \ get(a:result, 'data', {}) :
        \ {}

  let l:i = 0
  while l:i < l:len
    let l:current = l:i + l:start
    let l:x = s:draw_x(a:state, a:ctx, a:result, l:current)

    if !has_key(a:state.apply_highlights_cache, l:x) &&
          \ !empty(a:apply_highlights)
      let l:x_highlight = s:apply_highlights(a:apply_highlights, l:data, l:x)

      if l:x_highlight isnot 0
        let a:state.apply_highlights_cache[l:x] = l:x_highlight
      endif
    endif

    call add(l:xs, l:x)
    let l:i += 1
  endwhile

  " only 1 x, possible that it exceeds l:space
  if l:len == 1
    let l:x = l:xs[0]
    let l:is_selected = l:selected == 0

    if strdisplaywidth(l:x) > l:space
      let l:res = []

      let l:ellipsis = a:ctx.ellipsis
      let l:space_minus_ellipsis = l:space - strdisplaywidth(l:ellipsis)

      if has_key(a:state.apply_highlights_cache, l:x)
        let l:chunks = wilder#render#spans_to_chunks(
              \ l:x,
              \ a:state.apply_highlights_cache[l:x],
              \ a:ctx.highlights[l:is_selected ? 'selected' : 'default'],
              \ a:ctx.highlights[l:is_selected ? 'selected_accent' : 'accent'])
        let l:res += wilder#render#truncate_chunks(l:space_minus_ellipsis, l:chunks)
      else
        let l:x = wilder#render#truncate(l:space_minus_ellipsis, l:x)
        call add(l:res, [l:x, a:ctx.highlights[l:is_selected ? 'selected' : 'default']])
      endif

      call add(l:res, [l:ellipsis, a:ctx.highlights['default']])
      let l:padding = repeat(' ', l:space - strdisplaywidth(l:x))
      call add(l:res, [l:padding, a:ctx.highlights['default']])
      return l:res
    endif
  endif

  let l:current = l:start
  let l:res = [['']]
  let l:width = 0

  let l:i = 0
  while l:i < l:len
    if l:i > 0
      call add(l:res, [l:separator, a:ctx.highlights.separator])
      let l:width += strdisplaywidth(l:separator)
    endif

    let l:x = l:xs[l:i]
    let l:is_selected = l:selected == l:i + l:start

    if has_key(a:state.apply_highlights_cache, l:x)
      let l:chunks = wilder#render#spans_to_chunks(
            \ l:x,
            \ a:state.apply_highlights_cache[l:x],
            \ a:ctx.highlights[l:is_selected ? 'selected' : 'default'],
            \ a:ctx.highlights[l:is_selected ? 'selected_accent' : 'accent'])
      let l:res += chunks
    else
      call add(l:res, [l:x, a:ctx.highlights[l:is_selected ? 'selected' : 'default']])
    endif

    let l:width += strdisplaywidth(l:x)
    let l:i += 1
  endwhile

  call add(l:res, [repeat(' ', l:space - l:width)])
  return l:res
endfunction

function! s:apply_highlights(apply_highlights, data, x)
  for l:Apply_highlights in a:apply_highlights
    let l:spans = l:Apply_highlights({}, a:data, a:x)
    if l:spans isnot 0
      return l:spans
    endif
  endfor

  return 0
endfunction
