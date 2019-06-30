function! wilder#pipeline#component#result#make(...) abort
  let l:args = a:0 ? a:1 : {}
  return {ctx, xs -> map(xs, {_, x -> s:result(l:args, ctx, x)})}
endfunction

function! s:result(args, ctx, x) abort
  let l:x = type(a:x) is v:t_string ? {'value': a:x} : a:x

  for l:key in keys(a:args)
    let l:F = a:args[l:key]

    if l:key ==# 'value'
      if type(l:F) is v:t_func
        let l:x.value = l:F(a:ctx, l:x.value)
      else
        let l:x.value = l:F
      endif
      continue
    elseif l:key ==# 'meta'
      if type(l:F) is v:t_func
        let l:x.meta = l:F(a:ctx, get(l:x, 'meta', {}))
      else
        let l:x.meta = extend(get(l:x, 'meta', {}), a:args.meta)
      endif
      continue
    endif

    if has_key(l:x, l:key)
      if type(l:x[l:key]) is v:t_func
        let l:Prev = l:x[l:key]
      else
        let l:Prev = {ctx, x, def -> l:x[l:key]}
      endif
    else
      let l:Prev = {ctx, x, def -> def}
    endif

    let l:x[l:key] = s:make_func(l:F, l:Prev)
  endfor

  return l:x
endfunction

function! s:make_func(f, prev) abort
  return {ctx, x -> a:f(ctx, x, function('s:wrap_prev', [a:prev]))}
endfunction

function! s:wrap_prev(f, ctx, x, ...) abort
  if a:0
    return a:f(a:ctx, a:x, a:1)
  else
    return a:f(a:ctx, a:x, a:x)
  endif
endfunction
