function! wildsearch#render#component#spinner#make(args)
  let l:chars = get(a:args, 'chars', ['/', '|', '\', '-'])
  if type(l:chars) == v:t_string
    let l:chars = split(l:chars, '\zs')
  endif

  let l:done = get(a:args, 'done', ' ')

  let l:state = {
        \ 'chars': l:chars,
        \ 'index': 0,
        \ 'done': l:done,
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
    return a:state.done
  endif

  return a:state.chars[a:state.index]
endfunction

function! s:spinner(state, ctx, candidates)
  let a:state.index = (a:state.index + 1) % len(a:state.chars)
  return s:get_char(a:state, a:ctx, a:candidates)
endfunction
