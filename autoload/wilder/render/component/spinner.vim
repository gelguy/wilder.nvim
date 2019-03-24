function! wilder#render#component#spinner#make(args) abort
  let l:frames = get(a:args, 'frames', ['-', '\', '|', '/'])
  if type(l:frames) == v:t_string
    let l:frames = split(l:frames, '\zs')
  endif

  let l:done = get(a:args, 'done', ' ')
  let l:delay = get(a:args, 'delay', 0)
  let l:interval = get(a:args, 'interval', 100)

  let l:state = {
        \ 'frames': l:frames,
        \ 'done': l:done,
        \ 'delay': l:delay,
        \ 'interval': l:interval,
        \ 'index': 0,
        \ 'was_done': 1,
        \ 'timer': 0,
        \ 'start_time': reltime(),
        \ }

  return {
        \ 'value': {ctx, x -> s:spinner(l:state, ctx, x)},
        \ 'len': {ctx, x -> strdisplaywidth(s:get_char(l:state, ctx, x))},
        \ 'hl': get(a:args, 'hl', ''),
        \ }
endfunction

" set current_char in here so it is consistent with the actual rendered
" char. Due to reltime(), the char might be changed since len is called
" earlier
function! s:get_char(state, ctx, xs) abort
  if a:ctx.done
    let a:state.was_done = 1
    let a:state.index = -1
    return a:state.done
  endif

  if a:state.was_done
    let a:state.was_done = 0
    let a:state.index = len(a:state.frames) - 1

    if a:state.delay > 0
      let a:state.start_time = reltime()
    endif
  endif

  let l:elapsed = reltimefloat(reltime(a:state.start_time)) * 1000

  if a:state.delay > 0 && l:elapsed < a:state.delay
    let a:state.index = -1
    return a:state.done
  endif

  let l:elapsed_minus_delay = l:elapsed - a:state.delay
  let a:state.index = l:elapsed_minus_delay / a:state.interval

  let a:state.index = float2nr(fmod(a:state.index, len(a:state.frames)))
  return a:state.frames[a:state.index]
endfunction

function! s:spinner(state, ctx, xs) abort
  if a:state.timer
    call timer_stop(a:state.timer)
  endif

  if !a:ctx.done
    let l:elapsed = reltimefloat(reltime(a:state.start_time)) * 1000

    if l:elapsed < a:state.delay
      let l:wait_time = a:state.delay - l:elapsed + 1
    else
      let l:elapsed_minus_delay = l:elapsed - a:state.delay
      let l:wait_time = a:state.interval - fmod(l:elapsed_minus_delay, a:state.interval) + 1
    endif

    let a:state.timer = timer_start(float2nr(l:wait_time), {-> wilder#main#draw()})
  endif

  return a:state.index == -1 ? a:state.done : a:state.frames[a:state.index]
endfunction
