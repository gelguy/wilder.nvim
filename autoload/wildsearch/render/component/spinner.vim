function! wildsearch#render#component#spinner#make(args)
  let l:frames = get(a:args, 'frames', ['-', '\', '|', '/'])
  if type(l:frames) == v:t_string
    let l:frames = split(l:frames, '\zs')
  endif

  let l:done = get(a:args, 'done', ' ')
  let l:delay = get(a:args, 'delay', wildsearch#main#get_option('interval') * 2)

  let l:state = {
        \ 'frames': l:frames,
        \ 'index': 0,
        \ 'done': l:done,
        \ 'delay': l:delay,
        \ 'current_char': l:done,
        \ 'was_done': 1,
        \ 'start_time': reltime(),
        \ }

  let l:res = {
        \ 'f': {ctx, x -> s:spinner(l:state, ctx, x)},
        \ 'len': {ctx, x -> strdisplaywidth(s:get_char(l:state, ctx, x))},
        \ 'need_redraw': {ctx, x -> !ctx.done},
        \ }

  if has_key(a:args, 'hl')
    let l:res.hl = a:args.hl
  endif

  return l:res
endfunction

function! s:get_char(state, ctx, candidates)
  if a:ctx.done
    let a:state.was_done = 1
    let a:state.current_char = a:state.done
    return a:state.done
  endif

  if a:state.was_done == 1
    let a:state.start_time = reltime()
    let a:state.was_done = 0
    let a:state.index = -1
  endif

  if reltimefloat(reltime(a:state.start_time)) < (a:state.delay / 1000.0)
    let a:state.current_char = a:state.done
    return a:state.done
  endif

  " set current_char here so it is consistent with the actual render char
  " due to reltime(), the char might be changed since len is called earlier
  let a:state.index = (a:state.index + 1) % len(a:state.frames)
  let a:state.current_char = a:state.frames[a:state.index]
  return a:state.frames[a:state.index]
endfunction

function! s:spinner(state, ctx, candidates)
  return a:state.current_char
endfunction
