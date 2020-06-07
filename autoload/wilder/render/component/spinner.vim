function! wilder#render#component#spinner#make(args) abort
  let l:frames = get(a:args, 'frames', ['-', '\', '|', '/'])
  if type(l:frames) is v:t_string
    let l:frames = split(l:frames, '\zs')
  endif

  let l:Done = get(a:args, 'done', ' ')
  let l:delay = get(a:args, 'delay', 50)
  let l:interval = get(a:args, 'interval', 100)

  let l:state = {
        \ 'frames': l:frames,
        \ 'done': l:Done,
        \ 'frame': l:Done,
        \ 'delay': l:delay,
        \ 'interval': l:interval,
        \ 'index': 0,
        \ 'was_done': 1,
        \ 'timer': 0,
        \ 'start_time': reltime(),
        \ 'frame_done': 0,
        \ }

  return {
        \ 'value': {ctx, result -> s:spinner(l:state, ctx, result)},
        \ 'len': {ctx, result -> wilder#render#renderer#wildmenu#component_len(
        \   s:get_char(l:state, ctx, result), ctx, result)},
        \ 'hl': get(a:args, 'hl', ''),
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:pre_hook(state, ctx) abort
  call wilder#render#renderer#wildmenu#component_pre_hook(a:state.frames, a:ctx)
  call wilder#render#renderer#wildmenu#component_pre_hook(a:state.done, a:ctx)
endfunction

function! s:post_hook(state, ctx) abort
  call wilder#render#renderer#wildmenu#component_post_hook(a:state.frames, a:ctx)
  call wilder#render#renderer#wildmenu#component_post_hook(a:state.done, a:ctx)
endfunction

" set current_char in here so it is consistent with the actual rendered
" char. Due to reltime(), the char might be changed since len is called
" earlier
function! s:get_char(state, ctx, result) abort
  let a:state.frame_done = 1

  if a:state.timer
    call timer_stop(a:state.timer)
    let a:state.timer = 0
  endif

  if a:ctx.done
    let a:state.was_done = 1
    let a:state.index = -1
    let a:state.frame = a:state.done
    return a:state.frame
  endif

  if a:state.was_done
    let a:state.was_done = 0
    let a:state.index = 0
    let a:state.start_time = reltime()
  endif

  let l:elapsed = reltimefloat(reltime(a:state.start_time)) * 1000

  if l:elapsed < a:state.delay
    let l:wait_time = a:state.delay - l:elapsed + 1
  else
    let l:elapsed_minus_delay = l:elapsed - a:state.delay
    let l:wait_time = a:state.interval - fmod(l:elapsed_minus_delay, a:state.interval) + 1
  endif

  let a:state.timer = timer_start(float2nr(l:wait_time), {-> wilder#main#draw()})

  if a:state.delay > 0 && l:elapsed < a:state.delay
    let a:state.index = -1
    let a:state.frame = a:state.done
    return a:state.frame
  endif

  let l:elapsed_minus_delay = l:elapsed - a:state.delay
  let a:state.index = l:elapsed_minus_delay / a:state.interval

  let a:state.index = float2nr(fmod(a:state.index, len(a:state.frames)))
  let a:state.frame = a:state.frames[a:state.index]
  return a:state.frame
endfunction

function! s:spinner(state, ctx, result) abort
  if !a:state.frame_done
    call s:get_char(a:state, a:ctx, a:result)
  endif

  let a:state.frame_done = 0

  return a:state.frame
endfunction
