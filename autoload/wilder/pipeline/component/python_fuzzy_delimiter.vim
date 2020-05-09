function! wilder#pipeline#component#python_fuzzy_delimiter#make(args) abort
  return {ctx, x -> s:fuzzy_delimiter(a:args, ctx, x)}
endfunction

function! s:fuzzy_delimiter(args, ctx, x) abort
  if has_key(a:args, 'delimiter')
    if type(a:args.delimiter) == v:t_func
      let l:delimiter = a:args.delimiter(a:ctx, a:x)
    else
      let l:delimiter = a:args.delimiter
    endif
  else
    let l:delimiter = '(?:[^\w\s]|-)'
  endif

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
  let l:chars = split(a:x, '\zs')
  let l:len = len(l:chars)

  let l:first = 1
  let l:i = 0
  while l:i < l:len
    let l:char = l:chars[l:i]

    if l:char ==# '\'
      if l:i+1 < len(l:chars)
        let l:char .= l:chars[l:i+1]
        let l:i += 2
      else
        let l:char .= '\'
        let l:i += 1
      endif
      let l:escaped = 1
    elseif l:char ==# '^' ||
          \ l:char ==# '$' ||
          \ l:char ==# '*' ||
          \ l:char ==# '+' ||
          \ l:char ==# '?' ||
          \ l:char ==# '|' ||
          \ l:char ==# '(' ||
          \ l:char ==# ')' ||
          \ l:char ==# '{' ||
          \ l:char ==# '}' ||
          \ l:char ==# '[' ||
          \ l:char ==# ']'
        let l:char = '\' . l:char
        let l:i += 1
        let l:escaped = 1
    else
      let l:i += 1
      let l:escaped = 0
    endif

    if l:first
      if l:escaped || l:char ==# toupper(l:char)
        let l:res .= '(' . l:char . ')'
      elseif get(a:args, 'start_at_boundary', 0)
        let l:res .= '(?:(?:(?<=' . l:delimiter . ')|\b)('. l:char . ')|(' . toupper(l:char) . '))'
      else
        let l:res .= '('. l:char . '|' . toupper(l:char) . ')'
      endif

      let l:first = 0
      continue
    endif

    if !l:escaped && l:char ==# '.'
      if l:i + 1 < l:len && l:chars[l:i+1] ==# '.'
        let l:res .= '.'
      else
        let l:res .= '..*?'
      endif
    elseif l:escaped || l:char ==# toupper(l:char)
      let l:res .= '(?:' . l:word . '*?' . l:delimiter . '?(' . l:char . '))'
    else
      let l:res .= '(?:(' . l:char . ')|(' .
            \ toupper(l:char) . ')|' .
            \ l:word . '*?(' . toupper(l:char) . ')|' .
            \ l:word . '*?' . l:delimiter . '(' . l:char . ')|' .
            \ l:word . '*?' . l:delimiter . '(' . toupper(l:char) . '))'
    endif
  endwhile

  let l:res .= l:word . '*'

  return l:res
endfunction
