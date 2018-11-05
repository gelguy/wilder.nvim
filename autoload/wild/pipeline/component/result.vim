function! wild#pipeline#component#result#make(...) abort
  if a:0 == 0
    let l:F = {-> {}}
  elseif type(a:1) == v:t_func
    let l:F = a:1
  else
    let l:F = funcref(a:1)
  endif

  return {ctx, xs -> s:result(l:F, ctx, xs)}
endfunction

function! s:result(F, ctx, xs) abort
  let l:xs = map(copy(a:xs), {_, x -> type(x) == v:t_dict ? x : {'result': x}})

  let l:i = 0

  while l:i < len(l:xs)
    let l:ctx = copy(a:ctx)
    let l:ctx['i'] = l:i

    let l:xs[l:i] = extend(l:xs[l:i], a:F(l:ctx, l:xs[l:i]['result']))

    let l:i += 1
  endwhile

  return l:xs
endfunction
