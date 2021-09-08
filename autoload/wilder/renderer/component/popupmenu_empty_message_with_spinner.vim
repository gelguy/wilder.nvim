function! wilder#renderer#component#popupmenu_empty_message_with_spinner#(opts) abort
  let l:frames = get(a:opts, 'frames', ['-', '\', '|', '/'])
  if type(l:frames) is v:t_string
    let l:frames = split(l:frames, '\zs')
  endif

  let l:Message = get(a:opts, 'message', ' No candidates found ')

  if type(l:Message) is v:t_string
    let l:align = split(get(a:opts, 'align', 'middle-middle'), '-')
    let l:vertical = l:align[0]
    let l:horizontal = l:align[1]
    let l:message = l:Message

    let l:Message = {ctx, spinner_char, spinner_hl ->
          \ s:make_empty_message(ctx, l:vertical, l:horizontal, l:message, spinner_char, spinner_hl)}
  endif

  let l:Spinner = wilder#renderer#component#spinner#({
        \ 'num_frames': len(l:frames),
        \ 'delay': get(a:opts, 'delay', 50),
        \ 'interval': get(a:opts, 'interval', 100),
        \ })

  let l:state = {
        \ 'frames': l:frames,
        \ 'done': get(a:opts, 'done', '·'),
        \ 'message': l:Message,
        \ 'spinner': l:Spinner,
        \ 'timer': -1,
        \ }

  if has_key(a:opts, 'spinner_hl')
    let l:state.spinner_hl = a:opts.spinner_hl
  endif

  return {
        \ 'value': {ctx, -> s:message(l:state, ctx)},
        \ 'dynamic': 1,
        \ }
endfunction

function s:message(state, ctx) abort
  call timer_stop(a:state.timer)

  let [l:frame_number, l:wait_time] = a:state.spinner(a:ctx.done)

  if l:wait_time >= 0
    let a:state.timer = timer_start(l:wait_time, {-> wilder#main#draw()})
  endif

  if l:frame_number == -1
    let l:frame = a:state.done
  else
    let l:frame = a:state.frames[l:frame_number]
  endif

  let l:empty_message_hl = a:ctx.highlights.empty_message
  let l:spinner_hl = get(a:state, 'spinner_hl', l:empty_message_hl)

  return a:state.message(a:ctx, l:frame, l:spinner_hl)
endfunction

function! s:make_empty_message(ctx, vertical, horizontal, message, spinner_char, spinner_hl) abort
  let l:min_width = a:ctx.min_width
  let l:max_width = a:ctx.max_width
  let l:min_height = a:ctx.min_height
  let l:spinner_width = strdisplaywidth(a:spinner_char)

  let l:message = wilder#render#truncate(l:max_width - l:spinner_width, a:message)

  let l:empty_message_hl = a:ctx.highlights.empty_message
  let l:chunks = [[a:spinner_char, a:spinner_hl], [l:message, l:empty_message_hl]]

  let l:remaining_width = l:min_width - strdisplaywidth(l:message) - l:spinner_width
  if l:remaining_width > 0
    if a:horizontal ==# 'middle'
      let l:chunks = [[repeat(' ', l:remaining_width / 2)]] + l:chunks
      let l:chunks += [[repeat(' ', (l:remaining_width + 1) / 2)]]
    elseif a:horizontal ==# 'left'
      let l:chunks += [[repeat(' ', l:remaining_width)]]
    else
      " right
      let l:chunks = [[repeat(' ', l:remaining_width)]] + l:chunks
    endif
  endif

  let l:rows = [l:chunks]

  if l:min_height > 1
    " + 1 for the added space.
    let l:width = wilder#render#chunks_displaywidth(l:chunks)
    let l:padding_chunks = [[repeat(' ', l:width)]]
    let l:min_height_rows = repeat([l:padding_chunks], l:min_height - 1)

    if a:vertical ==# 'middle'
      let l:rows = repeat([l:padding_chunks], (l:min_height - 1) / 2) + l:rows
      let l:rows += repeat([l:padding_chunks], l:min_height / 2)
    elseif a:vertical ==# 'bottom'
      let l:rows = repeat([l:padding_chunks], l:min_height - 1) + l:rows
    else
      " bottom
      let l:rows += repeat([l:padding_chunks], l:min_height - 1)
    endif
  endif

  return l:rows
endfunction
