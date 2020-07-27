function! wilder#render#component#popupmenu_spinner#make(args) abort
  let l:placeholder = get(a:args, 'placeholder', ' %s ')

  let l:frames = get(a:args, 'frames', ['-', '\', '|', '/'])
  if type(l:frames) is v:t_string
    let l:frames = split(l:frames, '\zs')
  endif

  let l:delay = get(a:args, 'delay', 100)
  let l:interval = get(a:args, 'interval', 100)

  let l:spinner = wilder#render#component#spinner#make(
        \ len(l:frames), l:delay, l:interval)

  let l:state = {
        \ 'pos': get(a:args, 'pos', 'bottomright'),
        \ 'placeholder': l:placeholder,
        \ 'placeholder_needs_spinner': l:placeholder =~# '%s',
        \ 'spinner': l:spinner,
        \ 'frames': l:frames,
        \ 'frame_number': -1,
        \ 'got_char': 0,
        \ 'timer': 0,
        \ }

  if has_key(a:args, 'done')
    let l:state.done = a:args.done
  else
    let l:state.done = l:state.pos ==# 'cursor' ? '>' : ' '
  endif

  if has_key(a:args, 'hl')
    let l:state.hl = a:args.hl
  endif

  if has_key(a:args, 'selected_hl')
    let l:state.selected_hl = a:args.selected_hl
  endif

  if l:state.pos ==# 'cursor' ||
        \ l:state.pos ==# 'topleft' ||
        \ l:state.pos ==# 'bottomleft'
    let l:Space_used = {ctx, result ->
          \ !ctx.done && empty(result.value) ?
          \   [0, 0, 1, 0] :
          \   [strdisplaywidth(s:get_char(l:state, ctx.done)), 0, 0, 0]}
  else
    let l:Space_used = {ctx, result ->
          \ !ctx.done && empty(result.value) ?
          \   [1, 0, 0, 0] :
          \   [0, strdisplaywidth(s:get_char(l:state, ctx.done)), 0, 0]}
  endif

  return {
        \ 'decorate': {ctx, lines -> s:decorate(l:state, ctx, lines)},
        \ 'space_used': l:Space_used,
        \ }
endfunction

function! s:get_char(state, done)
  if a:done
    if a:state.timer
      let a:state.timer = 0
    endif

    call a:state.spinner.stop()
    let a:state.frame_number = -1
    return a:state.done
  endif

  call a:state.spinner.start()
  let [l:frame_number, l:wait_time] =
        \ a:state.spinner.get_frame_number()

  if l:wait_time >= 0
    call timer_stop(a:state.timer)
    let a:state.timer = timer_start(float2nr(l:wait_time),
          \ {-> wilder#main#draw()})
  endif

  if l:frame_number == -1
    let a:state.char = a:state.done
    let a:state.frame_number = -1
  else
    let a:state.char = a:state.frames[l:frame_number]
    let a:state.frame_number = l:frame_number
  endif

  let a:state.got_char = 1
  return a:state.char
endfunction

function! s:decorate(state, ctx, lines) abort
  let l:hl = get(a:state, 'hl', a:ctx.highlights.default)

  if a:state.got_char
    let l:char = a:state.char
  else
    let l:char = s:get_char(a:state, a:ctx.done)
  endif

  let a:state.got_char = 0

  if !a:ctx.done && empty(a:lines)
    if a:state.frame_number == -1
      return
    endif

    if a:state.placeholder_needs_spinner
      let l:message = printf(a:state.placeholder, l:char)
    else
      let l:message = a:state.placeholder
    endif

    return [[[l:message, l:hl]]]
  endif

  let l:width = strdisplaywidth(l:char)
  let l:padding = repeat(' ', l:width)

  let l:selected = a:ctx.selected - a:ctx.page[0]
  let l:selected_hl = get(a:state, 'selected_hl', a:ctx.highlights.selected)

  if a:state.pos ==# 'cursor'
    if a:state.frame_number == -1 && a:ctx.selected == -1
      let l:char = l:padding
    endif

    return map(a:lines, {i, line ->
          \ [[a:ctx.selected == -1 && i == 0 || l:selected == i ?
          \   l:char :
          \   l:padding,
          \   l:selected == i ? l:selected_hl : l:hl]] + line})
  endif

  if a:state.pos ==# 'topleft'
    return map(a:lines, {i, line ->
          \ [[i == 0 ? l:char : l:padding,
          \   l:selected == i ? l:selected_hl : l:hl]] + line})
  endif

  if a:state.pos ==# 'topright'
    return map(a:lines, {i, line -> line +
          \ [[i == 0 ? l:char : l:padding,
          \   l:selected == i ? l:selected_hl : l:hl]]})
  endif

  if a:state.pos ==# 'bottomleft'
    return map(a:lines, {i, line ->
          \ [[i == len(a:lines) - 1 ? l:char : l:padding,
          \   l:selected == i ? l:selected_hl : l:hl]] + line})
  endif

  return map(a:lines, {i, line -> line +
        \ [[i == len(a:lines) - 1 ? l:char : l:padding,
        \   l:selected == i ? l:selected_hl : l:hl]]})
endfunction
