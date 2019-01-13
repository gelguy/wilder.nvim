function! wilder#pipeline#component#result#make(...) abort
  let l:args = a:0 ? a:1 : {}
  return {ctx, x -> s:result(l:args, ctx, x)}
endfunction

function! s:result(args, ctx, x) abort
  let l:result = type(a:x) is v:t_dict ? copy(a:x) : {'x': a:x}

  for l:key in keys(a:args)
    if type(a:args[l:key]) is v:t_string
      let l:F = function(a:args[l:key])
    else
      let l:F = a:args[l:key]
    endif

    if l:key ==# 'replace'
      let l:result[l:key] = l:F
      continue
    endif

    if has_key(l:result, l:key)
      let l:Prev = l:result[l:key]

      if type(l:Prev) is v:t_string
        let l:Prev = function(l:Prev)
      endif
    else
      let l:Prev = {ctx, x -> x}
    endif

    let l:result[l:key] = {ctx, x -> l:F(ctx, x, l:Prev)}
  endfor

  return l:result
endfunction
