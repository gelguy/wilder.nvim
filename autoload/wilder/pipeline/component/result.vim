function! wilder#pipeline#component#result#make(...) abort
  let l:args = a:0 ? a:1 : {}
  return {ctx, xs -> s:result(l:args, ctx, xs)}
endfunction

function! s:result(args, ctx, xs) abort
  let l:result = type(a:xs) isnot v:t_dict ?
        \ {'xs': a:xs} :
        \ a:xs

  for l:key in keys(a:args)
    let l:F = a:args[l:key]

    if type(l:F) is v:t_list
      let l:result[l:key] = get(l:result, l:key, []) + l:F
    elseif type(l:F) is v:t_dict
      let l:result[l:key] = extend(get(l:result, l:key, {}), l:F)
    elseif type(l:F) is v:t_func
      let l:result[l:key] = l:F(a:ctx, get(l:result, l:key, v:null))
    else
      let l:result[l:key] = l:F
    endif
  endfor

  return l:result
endfunction
