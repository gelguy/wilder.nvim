function! wilder#render#component#spinner#make(num_frames, delay, interval) abort
  let l:state = {
        \ 'frame_number': -1,
        \ 'num_frames': a:num_frames,
        \ 'delay': a:delay,
        \ 'interval': a:interval,
        \ 'start_time': reltime(),
        \ 'running': 0,
        \ }

  return {
        \ 'start': {-> s:start(l:state)},
        \ 'get_frame_number': {-> s:get_frame_number(l:state)},
        \ 'stop': {-> s:stop(l:state)},
        \ }
endfunction

function! s:start(state)
  if !a:state.running
    let a:state.running = 1
    let a:state.frame_number = 0
    let a:state.start_time = reltime()
  endif
endfunction

function! s:get_frame_number(state) abort
  if !a:state.running || a:state.num_frames == 0
    return [-1, -1]
  endif

  let l:elapsed = reltimefloat(reltime(a:state.start_time)) * 1000

  if l:elapsed < a:state.delay
    let l:wait_time = a:state.delay - l:elapsed + 1
  else
    let l:elapsed_minus_delay = l:elapsed - a:state.delay
    let l:wait_time = a:state.interval - fmod(l:elapsed_minus_delay, a:state.interval) + 1
  endif

  if a:state.delay > 0 && l:elapsed < a:state.delay
    let a:state.frame_number = -1
  else
    let l:elapsed_minus_delay = l:elapsed - a:state.delay
    let l:index = l:elapsed_minus_delay / a:state.interval
    let a:state.frame_number = float2nr(fmod(l:index, a:state.num_frames))
  endif

  return [a:state.frame_number, l:wait_time]
endfunction

function! s:stop(state) abort
  let a:state.running = 0
endfunction
