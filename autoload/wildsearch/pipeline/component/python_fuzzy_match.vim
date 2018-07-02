function! wildsearch#pipeline#component#python_fuzzy_match#make(args)
  return {ctx, x -> s:make(ctx, x)}
endfunction

function! s:make(ctx, x)
  let l:res = ''
  let l:i = 0

  while l:i < len(a:x)
    if a:x[l:i] ==# '\'
      let l:res .= a:x[l:i : l:i+2]
      let l:i += 2
    else
      let l:res .= a:x[l:i]
      let l:i += 1
    endif

    let l:res .= '\w*'

    if l:i < len(a:x)
      let l:res .= '?'
    endif
  endwhile

  return l:res
endfunction
