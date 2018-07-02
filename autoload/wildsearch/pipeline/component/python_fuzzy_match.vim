function! wildsearch#pipeline#component#python_fuzzy_match#make(args)
  return {ctx, x -> s:make(a:args, ctx, x)}
endfunction

function! s:make(args, ctx, x)
  if has_key(a:args, 'char')
    if type(a:args.char) == v:t_string
      let l:char = a:args.char
    else
      let l:char = a:args.char(a:ctx, a:x)
    endif
  else
    let l:char = '\w'
  endif

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

    let l:res .= l:char . '*'

    if l:i < len(a:x)
      let l:res .= '?'
    endif
  endwhile

  return l:res
endfunction
