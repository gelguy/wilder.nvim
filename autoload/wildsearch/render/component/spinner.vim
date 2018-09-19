function! wildsearch#render#component#spinner#make(args) abort
  let l:frames = get(a:args, 'frames', ['-', '\', '|', '/'])
  if type(l:frames) == v:t_string
    let l:frames = split(l:frames, '\zs')
  endif

  let l:done = get(a:args, 'done', ' ')
  let l:delay = get(a:args, 'delay', 0) / 1000.0
  let l:interval = get(a:args, 'interval', 0) / 1000.0

  let l:state = {
        \ 'frames': l:frames,
        \ 'done': l:done,
        \ 'delay': l:delay,
        \ 'interval': l:interval,
        \ 'index': 0,
        \ 'current_char': l:done,
        \ 'was_done': 1,
        \ 'start_time': reltime(),
        \ 'last_new_state_time': reltime(),
        \ }

  let l:res = {
        \ 'stl': {ctx, x -> s:spinner(l:state, ctx, x)},
        \ 'len': {ctx, x -> strdisplaywidth(s:get_char(l:state, ctx, x))},
        \ 'redraw': {ctx, x -> !ctx.done},
        \ }

  if has_key(a:args, 'hl')
    let l:res.hl = a:args.hl
  endif

  return l:res
endfunction

function! s:get_char(state, ctx, xs) abort
  if a:ctx.done
    let a:state.was_done = 1
    let a:state.current_char = a:state.done
    return a:state.done
  endif

  if a:state.was_done == 1
    let a:state.was_done = 0
    let a:state.index = -1

    if a:state.delay > 0
      let a:state.start_time = reltime()
    endif
  endif

  if a:state.delay > 0 && reltimefloat(reltime(a:state.start_time)) < a:state.delay
    let a:state.current_char = a:state.done
    return a:state.done
  endif

  if a:state.interval <= 0 || reltimefloat(reltime(a:state.last_new_state_time)) > a:state.interval
    " set current_char in here so it is consistent with the actual rendered
    " char. Due to reltime(), the char might be changed since len is called
    " earlier
    let a:state.index = (a:state.index + 1) % len(a:state.frames)
    let a:state.current_char = a:state.frames[a:state.index]

    if a:state.interval > 0
      let a:state.last_new_state_time = reltime()
    endif
  endif

  return a:state.frames[a:state.index]
endfunction

function! s:spinner(state, ctx, xs) abort
  return a:state.current_char
endfunction
