function! wilder#renderer#spinner#make(opts) abort
  let l:state = {
        \ 'num_frames': a:opts.num_frames,
        \ 'delay': a:opts.delay,
        \ 'interval': a:opts.interval,
        \ 'index': -1,
        \ 'was_done': 1,
        \ 'timer': 0,
        \ 'start_time': reltime(),
        \ }

  return {
        \ 'spin': {ctx, result -> s:spin(l:state, ctx, result)},
        \ }
endfunction

function! s:spin(state, ctx, result) abort
  if a:state.timer
    call timer_stop(a:state.timer)
    let a:state.timer = 0
  endif

  " Result has finished.
  if a:ctx.done
    let a:state.was_done = 1
    let a:state.index = -1
    return a:state.index
  endif

  " Previous result was finished. Start spinner again.
  if a:state.was_done
    let a:state.was_done = 0
    let a:state.index = 0
    let a:state.start_time = reltime()
  endif

  let l:elapsed = reltimefloat(reltime(a:state.start_time)) * 1000

  " Calculate time to next frame. Either wait for delay to be over or wait for
  " next frame.
  if l:elapsed < a:state.delay
    let l:wait_time = a:state.delay - l:elapsed + 1
  else
    let l:elapsed_minus_delay = l:elapsed - a:state.delay
    let l:wait_time = a:state.interval - fmod(l:elapsed_minus_delay, a:state.interval) + 1
  endif

  let a:state.timer = timer_start(float2nr(l:wait_time), {-> wilder#main#draw()})

  if a:state.delay > 0 && l:elapsed < a:state.delay
    let a:state.index = -1
    return a:state.index
  endif

  let l:elapsed_minus_delay = l:elapsed - a:state.delay
  let a:state.index = l:elapsed_minus_delay / a:state.interval

  let a:state.index = float2nr(fmod(a:state.index, a:state.num_frames))
  return a:state.index
endfunction
