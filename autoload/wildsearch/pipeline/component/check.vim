function! wildsearch#pipeline#component#check#make(args)
  return {ctx, x -> s:check(a:args, ctx, x)}
endfunction

function s:check(checks, ctx, x)
  let l:i = 0

  for l:Check in a:checks
    if !l:Check(a:ctx, a:x)
      return v:false
    endif
  endfor

  return a:x
endfunction
