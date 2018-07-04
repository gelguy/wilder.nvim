function! wildsearch#pipeline#component#python_fuzzy_match#make(args)
  return {ctx, x -> s:fuzzy_match(a:args, ctx, x)}
endfunction

function! s:fuzzy_match(args, ctx, x)
  if has_key(a:args, 'word')
    if type(a:args.word) == v:t_string
      let l:word = a:args.word
    else
      let l:word = a:args.word(a:ctx, a:x)
    endif
  else
    let l:word = '\w'
  endif

  let l:res = ''
  let l:len = strchars(a:x)

  let l:i = 0
  while l:i < l:len
    let l:char = strcharpart(a:x, l:i, 1)

    if l:char ==# '\'
      let l:res .= strcharpart(a:x, l:i, 2)
      let l:i += 2
    else
      let l:res .= l:char
      let l:i += 1
    endif

    let l:res .= l:word . '*'

    if l:i < l:len
      let l:res .= '?'
    endif
  endwhile

  return l:res
endfunction
