function! wilder#renderer#component#popupmenu_empty_message_with_spinner#(opts) abort
  let l:frames = get(a:opts, 'frames', ['-', '\', '|', '/'])
  if type(l:frames) is v:t_string
    let l:frames = split(l:frames, '\zs')
  endif

  let l:Message = get(a:opts, 'message', ' No candidates found ')

  if type(l:Message) is v:t_string
    let l:align = get(a:opts, 'align', 'right') ==# 'left'
    let l:message = l:Message

    let l:Message = {ctx, spinner_char, spinner_hl -> s:make_empty_message(ctx, l:align, l:message, spinner_char, spinner_hl)}
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

function! s:make_empty_message(ctx, is_left_align, message, spinner_char, spinner_hl) abort
  let l:min_width = a:ctx.min_width
  let l:max_width = a:ctx.max_width

  let l:spinner_width = strdisplaywidth(a:spinner_char)
  let l:message = wilder#render#truncate(l:max_width - l:spinner_width - 2, a:message)
  let l:message .= repeat(' ', l:min_width - strdisplaywidth(l:message) - l:spinner_width - 2)

  let l:empty_message_hl = a:ctx.highlights.empty_message
  let l:chunks = [[l:message, l:empty_message_hl]]

  if a:is_left_align
    call insert(l:chunks, [a:spinner_char, a:spinner_hl])
    call insert(l:chunks, [' ', l:empty_message_hl])
  else
    call add(l:chunks, [a:spinner_char, a:spinner_hl])
    call add(l:chunks, [' ', l:empty_message_hl])
  endif

  return l:chunks
endfunction
