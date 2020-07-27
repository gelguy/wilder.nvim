function! wilder#render#renderer#popupmenu#make(args) abort
  let l:highlights = copy(get(a:args, 'highlights', {}))
  let l:state = {
        \ 'highlights': extend(l:highlights, {
        \   'default': get(a:args, 'hl', 'Pmenu'),
        \   'selected': get(a:args, 'selected_hl', 'PmenuSel'),
        \   'error': get(a:args, 'error_hl', 'Pmenu'),
        \ }, 'keep'),
        \ 'ellipsis': wilder#render#to_printable(get(a:args, 'ellipsis', '...')),
        \ 'max_height': get(a:args, 'max_height', 10),
        \ 'max_width': get(a:args, 'max_width', 50),
        \ 'decorators': get(a:args, 'decorators', [
        \   wilder#popupmenu_padding(1, 1),
        \   wilder#popupmenu_spinner(),
        \  ]),
        \ 'scrolloff': get(a:args, 'scrolloff', 3),
        \ 'page': [-1, -1],
        \ 'pos': 0,
        \ 'buf': -1,
        \ 'win': -1,
        \ 'draw_cache': {},
        \ 'apply_highlights_cache': {},
        \ 'current_width': 0,
        \ 'run_id': -1,
        \ 'ns_id': nvim_create_namespace('')
        \ }

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

  return {
        \ 'render': {ctx, result -> s:render(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:render(state, ctx, result) abort
  let l:max_height = a:state.max_height > 0 ?
        \ a:state.max_height :
        \ &lines - 1
  let l:max_width = a:state.max_width > 0 ?
        \ a:state.max_width :
        \ &columns - 1

  let l:height_used = 0
  let l:width_used = 0
  let l:offset = 0
  for l:decorator in a:state.decorators
    if has_key(l:decorator, 'space_used')
      let l:Space_used = l:decorator.space_used

      if type(l:Space_used) is v:t_func
        let l:Space_used = l:Space_used(a:ctx, a:result)
      endif

      let l:width_used += l:Space_used[0] + l:Space_used[1]
      let l:offset += l:Space_used[0]
      let l:height_used += l:Space_used[2] + l:Space_used[3]
    endif
  endfor

  let l:use_decorators = l:max_width - l:width_used >= len(a:state.ellipsis) &&
        \ l:max_height >= l:height_used

  if l:use_decorators
    let l:max_height -= l:height_used
    let l:max_width -= l:width_used
  endif

  if l:max_height > len(a:result.value)
    let l:max_height = len(a:result.value)
  endif

  let a:state.page = s:make_page(a:state, a:ctx, a:result, l:max_height)

  " handle scrolloff
  if a:state.scrolloff > 0 &&
        \ a:ctx.selected != -1 &&
        \ l:max_height > a:state.scrolloff
    if a:ctx.direction < 0
      while a:state.page[0] > 0 &&
            \ a:ctx.selected - a:state.page[0] < a:state.scrolloff
        let a:state.page[0] -= 1
        let a:state.page[1] -= 1
      endwhile
    else
      let l:len = len(a:result.value)
      while a:state.page[1] < l:len - 1 &&
            \ a:state.page[1] - a:ctx.selected < a:state.scrolloff
        let a:state.page[0] += 1
        let a:state.page[1] += 1
      endwhile
    endif
  endif

  let l:lines = s:make_hl_lines(
        \ a:state, a:ctx, a:result, a:state.page, l:max_width)

  let a:ctx.page = a:state.page
  let a:ctx.highlights = a:state.highlights
  let a:ctx.result = a:result

  if l:use_decorators
    for l:decorator in a:state.decorators
      let l:lines = l:decorator.decorate(a:ctx, l:lines)
    endfor
  endif

  let l:in_sandbox = 0
  try
    call nvim_buf_set_lines(a:state.buf, 0, -1, v:true, [])
  catch /E523/
    " might be in sandbox due to expr mapping
    let l:in_sandbox = 1
  endtry

  if l:in_sandbox
    let l:state = copy(a:state)
    call timer_start(0, {-> s:render_lines(l:state, a:ctx, a:result, l:lines, l:offset)})
  else
    call s:render_lines(a:state, a:ctx, a:result, l:lines, l:offset)
  endif
endfunction

function! s:make_page(state, ctx, result, height) abort
  if empty(a:result.value)
    return [-1, -1]
  endif

  let l:page = a:state.page
  let l:selected = a:ctx.selected

  if l:page != [-1, -1] && l:selected != -1 && l:selected >= l:page[0] && l:selected <= l:page[1]
    " check if page start to page end still fits within height
    " height might have changed due to resizing or due to custom decorators
    let l:page_height = l:page[1] - l:page[0] + 1

    if l:page_height == a:height
      return l:page
    endif

    let l:new_page_end = a:height + l:page[0] - 1
    if l:new_page_end >= 0
      let l:new_page = [l:page[0], l:new_page_end]

      if l:page_height < a:height
        return l:new_page
      endif

      " original page is not contained within height
      " check whether selected is still within page with new height
      if l:selected <= l:new_page[1]
        return l:new_page
      endif
    endif

    " continue below otherwise
  endif

  if l:selected == -1
    let l:selected = 0
  endif

  if a:ctx.direction < 0
    let l:page_end = l:selected
    let l:page_start = l:page_end - a:height + 1

    if l:page_start < 0
      return [0, a:height - 1]
    endif

    return [l:page_start, l:page_end]
  endif

  let l:page_start = l:selected
  let l:page_end = l:page_start + a:height - 1

  if l:page_end > len(a:result.value) - 1
    let l:page_end = len(a:result.value) - 1
    return [l:page_end - a:height + 1, l:page_end]
  endif
  return [l:selected, l:page_end]
endfunction

function! s:make_hl_lines(state, ctx, result, page, max_width) abort
  if a:state.run_id != a:ctx.run_id
    let a:state.draw_cache = {}
    let a:state.apply_highlights_cache = {}

    let a:state.current_width = 0
  endif
  let l:s = a:state.run_id
  let a:state.run_id = a:ctx.run_id

  let l:xs = []
  let l:max_width = a:state.current_width
  if a:page[0] != -1 && a:page[1] != -1
    let l:start = a:page[0]
    let l:end = a:page[1]

    let l:i = l:start
    while l:i <= l:end
      let l:x = wilder#render#renderer#draw_x(a:state.draw_cache, a:ctx, a:result, l:i)
      call add(l:xs, l:x)

      let l:width = strdisplaywidth(l:x)
      if l:width > l:max_width
        let l:max_width = l:width
      endif
      let l:i += 1
    endwhile
  endif

  if a:max_width > 0 && l:max_width > a:max_width
    let l:max_width = a:max_width
  endif
  let a:state.current_width = l:max_width

  let l:lines = []

  let l:data = type(a:result) is v:t_dict ?
        \ get(a:result, 'data', {}) :
        \ {}
  call wilder#render#renderer#cache_apply_highlights(
        \ a:state.apply_highlights_cache, a:state.apply_highlights, a:ctx, l:xs, l:data)

  let l:i = 0
  while l:i < len(l:xs)
    let l:x = l:xs[l:i]
    let l:is_selected = a:ctx.selected == l:i + a:state.page[0]
    let l:hl = a:state.highlights[l:is_selected ? 'selected' : 'default']

    if has_key(a:state.apply_highlights_cache, l:x)
      let l:chunks = wilder#render#spans_to_chunks(
            \ l:x,
            \ a:state.apply_highlights_cache[l:x],
            \ a:state.highlights[l:is_selected ? 'selected' : 'default'],
            \ a:state.highlights[l:is_selected ? 'selected_accent' : 'accent'])
    else
      let l:chunks = [[l:x, l:hl]]
    endif

    let l:chunks = wilder#render#truncate_or_pad_chunks(
          \ l:max_width, l:chunks, l:hl, a:state.ellipsis, ' ')
    call wilder#render#normalise_chunks(a:state.highlights['default'], l:chunks)

    call add(l:lines, l:chunks)
    let l:i += 1
  endwhile

  return l:lines
endfunction

function! s:render_lines(state, ctx, result, lines, offset) abort
  if empty(a:lines)
    call s:win_close(a:state)
    return
  elseif a:state.win == -1
    let a:state.win = wilder#render#renderer#open_win(
          \ a:state.buf, 0, 0, &lines-1, &columns)
  endif

  let l:selected = a:ctx.selected
  let l:Pos = get(a:result, 'pos', 0)
  if type(l:Pos) is v:t_list
    let l:Pos = l:Pos[0]
    let l:Pos = l:Pos({},
          \ l:selected == -1 ? v:null : a:result.value[l:selected],
          \ get(a:result, 'data', {}))
  endif

  " include cmdtypechar
  let l:pos = (l:Pos + 1 - a:offset) % &columns

  let l:height = len(a:lines)
  let l:width = 0
  for l:chunk in a:lines[0]
    let l:width += strdisplaywidth(l:chunk[0])
  endfor

  " set row to the bottom, nvim will automatically realign the float to fit
  call nvim_win_set_config(a:state.win, {
        \ 'relative': 'editor',
        \ 'row': &lines - 1,
        \ 'col': l:pos,
        \ 'height': l:height,
        \ 'width': l:width,
        \ })

  call nvim_buf_clear_namespace(a:state.buf, a:state.ns_id, 0, -1)
  call nvim_buf_set_lines(a:state.buf, 0, -1, v:true, [])

  let l:i = 0
  while l:i < len(a:lines)
    let l:text = ''
    let l:chunks = a:lines[l:i]
    for l:elem in l:chunks
      let l:text .= l:elem[0]
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

function! s:win_close(state) abort
  if a:state.win != -1
    let l:win = a:state.win
    let a:state.win = -1
    " cannot call nvim_win_close() while cmdline-window is open
    if getcmdwintype() ==# ''
      call nvim_win_close(l:win, 1)
    else
      execute 'autocmd CmdWinLeave * ++once call timer_start(0, {-> nvim_win_close(' . l:win . ', 0)})'
    endif
  endif
endfunction

function! s:pre_hook(state, ctx) abort
  " Fixes bug where search highlighting is not applied properly
  if has('nvim-0.4')
    let l:old_cursorline = &cursorline
    let &cursorline = 0
  endif

  if a:state.buf == -1
    let a:state.buf = nvim_create_buf(v:false, v:true)
  endif
endfunction

function! s:post_hook(state, ctx) abort
  if a:state.buf != -1
    call nvim_buf_clear_namespace(a:state.buf, a:state.ns_id, 0, -1)
  endif

  call s:win_close(a:state)
endfunction
