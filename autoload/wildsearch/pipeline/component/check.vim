function! wildsearch#pipeline#component#check#make(args)
  return {ctx, x -> s:check(a:args, ctx, x)}
endfunction

function s:check(checks, ctx, x)
  let l:i = 0

  while l:i < len(a:checks)
    let l:ok = a:checks[l:i](a:ctx, a:x)

    if !l:ok
      return v:false
    endif

    let l:i += 1
  endwhile

  return a:x
endfunction
