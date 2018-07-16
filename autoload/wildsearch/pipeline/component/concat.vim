function! wildsearch#pipeline#component#concat#make()
  return {ctx, x -> s:concat(ctx, x)}
endfunction

function s:concat(ctx, x)
  let l:res = []

  for l:elem in a:x
    let l:res += l:elem
  endfor

  return l:res
endfunction
