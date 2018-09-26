func wildsearch#getcompletion#skip_plus_command#do(ctx)
  let a:ctx.pos += 1

  while a:ctx.pos < len(a:ctx.cmdline)
        \ && !wildsearch#getcompletion#is_whitespace(a:ctx.cmdline[a:ctx.pos])
    if a:ctx.cmdline[a:ctx.pos] ==# '\\' &&
          \ a:ctx.pos + 1 < len(a:ctx.cmdline)
      let a:ctx.pos += 1
    endif

    " TODO: multibyte
    let a:ctx.pos += 1
  endwhile
endfunc
