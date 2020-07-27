function! wilder#render#component#wildmenu_spinner#make(args) abort
  let l:frames = get(a:args, 'frames', ['-', '\', '|', '/'])
  if type(l:frames) is v:t_string
    let l:frames = split(l:frames, '\zs')
  endif

  let l:delay = get(a:args, 'delay', 100)
  let l:interval = get(a:args, 'interval', 100)
  let l:spinner = wilder#render#component#spinner#make(
        \ len(l:frames), l:delay, l:interval)

  let l:state = {
        \ 'frames': l:frames,
        \ 'spinner': l:spinner,
        \ 'done': get(a:args, 'done', ' '),
        \ 'timer': 0,
        \ 'char': '',
        \ 'got_char': 0,
        \ }

  return {
        \ 'value': {ctx, result -> s:spinner(l:state, ctx, result)},
        \ 'len': {ctx, result -> wilder#render#renderer#wildmenu#component_len(
        \   s:get_char(l:state, ctx.done), ctx, result)},
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
  call wilder#render#renderer#wildmenu#component_post_hook(a:state.done, a:ctx)
  call wilder#render#renderer#wildmenu#component_post_hook(a:state.frames, a:ctx)
endfunction

function! s:get_char(state, done)
  if a:done
    if a:state.timer
      call timer_stop(a:state.timer)
      let a:state.timer = 0
    endif

    call a:state.spinner.stop()
    let a:state.char = a:state.done
  else
    call a:state.spinner.start()
    let [l:frame_number, l:wait_time] = a:state.spinner.get_frame_number()

    if l:wait_time >= 0
      call timer_stop(a:state.timer)
      let a:state.timer = timer_start(float2nr(l:wait_time),
            \ {-> wilder#main#draw()})
    endif

    if l:frame_number == -1
      let a:state.char = a:state.done
    else
      let a:state.char = a:state.frames[l:frame_number]
    endif
  endif

  let a:state.got_char = 1
  return a:state.char
endfunction

function! s:spinner(state, ctx, result) abort
  if a:state.got_char
    let l:Char = a:state.char
  else
    let l:Char = s:get_char(a:state, a:ctx.done)
  endif

  let a:state.got_char = 0

  return l:Char
endfunction
