function! wilder#pipeline#component#result#make(...) abort
  let l:args = a:0 ? a:1 : {}
  return {ctx, r -> s:result(l:args, ctx, r)}
endfunction

function! s:result(args, ctx, r) abort
  let l:result = type(a:r) is v:t_dict ? copy(a:r) : {'x': a:r}

  for l:key in keys(a:args)
    let l:F = a:args[l:key]

    if l:key ==# 'replace'
      let l:result.replace = l:F
      continue
    elseif l:key ==# 'x'
      let l:result.x = l:F(a:ctx, a:r.x)
      continue
    endif

    if has_key(l:result, l:key)
      let l:Prev = l:result[l:key]
    else
      let l:Prev = {ctx, x -> x}
    endif

    let l:result[l:key] = {ctx, x -> l:F(ctx, x, l:Prev)}
  endfor

  return l:result
endfunction
