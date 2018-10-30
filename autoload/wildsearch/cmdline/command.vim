function! wildsearch#cmdline#command#do(ctx) abort
  " check for -attr
  while a:ctx.cmdline[a:ctx.pos] ==# '-'
    let a:ctx.pos += 1
    let l:arg_start = a:ctx.pos

    " skip to white space
    while a:ctx.pos < len(a:ctx.cmdline)
      if wildsearch#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
        break
      endif

      let a:ctx.pos += 1
    endwhile

    " cursor ends in attr
    if a:ctx.pos == len(a:ctx.cmdline)
      " check if cursor is in -attr= part
      let a:ctx.pos = l:arg_start

      while a:ctx.pos < len(a:ctx.cmdline)
        if a:ctx.cmdline[a:ctx.pos] ==# '='
          let a:ctx.pos += 1

          return
        endif

        let a:ctx.pos += 1
      endwhile

      " in -attr part
      let a:ctx.pos = l:arg_start
      return
    endif

    if !wildsearch#cmdline#main#skip_whitespace(a:ctx)
      return
    endif
  endwhile

  " command name
  " skip to white space
  while a:ctx.pos < len(a:ctx.cmdline)
    if wildsearch#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
      break
    endif

    let a:ctx.pos += 1
  endwhile

  " cursor ends at command name
  if a:ctx.pos == len(a:ctx.cmdline)
    return
  endif

  " new command
  let a:ctx.cmd = ''

  call wildsearch#cmdline#main#do(a:ctx)
endfunction
