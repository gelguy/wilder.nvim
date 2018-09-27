function! wildsearch#getcompletion#sign#do(ctx) abort
  let l:arg_start = a:ctx.pos

  if !wildsearch#getcompletion#skip_nonwhitespace(a:ctx)
    let a:ctx.pos = l:arg_start
    return
  endif

  if !wildsearch#getcompletion#main#skip_whitespace(a:ctx)
    return
  endif

  let l:arg_start = a:ctx.pos

  if !wildsearch#getcompletion#skip_nonwhitespace(a:ctx)
    let a:ctx.pos = l:arg_start
    return
  endif

  while a:ctx.pos < len(a:ctx.cmdline)
    if !wildsearch#getcompletion#main#skip_whitespace(a:ctx)
      return
    endif

    let l:arg_start = a:ctx.pos

    if !wildsearch#getcompletion#skip_nonwhitespace(a:ctx)
      break
    endif
  endwhile

  let a:ctx.pos = l:arg_start

  while a:ctx.pos < len(a:ctx.cmdline)
    if a:ctx.cmdline[a:ctx.pos] ==# '='
      let a:ctx.pos += 1
      return
    endif

    let a:ctx.pos += 1
  endwhile

  let a:ctx.pos = l:arg_start
endfunction
