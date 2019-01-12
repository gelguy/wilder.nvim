function! wilder#cmdline#set#do(ctx) abort
  let l:arg_start = a:ctx.pos
  let l:in_option_arg = 0

  while a:ctx.pos < len(a:ctx.cmdline)
    let l:char = a:ctx.cmdline[a:ctx.pos]

    if l:char ==# '\' &&
          \ a:ctx.pos + 1 < a:ctx.cmdline
      let a:ctx.pos += 1
    endif

    if wilder#cmdline#main#is_whitespace(l:char)
      let l:arg_start = a:ctx.pos + 1
      let l:in_option_arg = 0
    endif

    if !l:in_option_arg
      if l:char ==# '=' || l:char ==# ':'
        let l:arg_start = a:ctx.pos + 1
        let l:in_option_arg = 1
      endif

      if (l:char ==# '+' || l:char ==# '-' || l:char ==# '^') &&
            \ a:ctx.cmdline[a:ctx.pos + 1] ==# '='
        let l:arg_start = a:ctx.pos + 2
        let l:in_option_arg = 1
      endif
    endif

    let a:ctx.pos += 1
  endwhile

  if !l:in_option_arg
    let l:arg = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]

    if l:arg[0:1] ==# 'no'
      let a:ctx.pos = l:arg_start + 2
      return
    elseif l:arg[0:2] ==# 'inv'
      let a:ctx.pos = l:arg_start + 3
      return
    endif
  endif

  let a:ctx.pos = l:arg_start
endfunction
