function! wildsearch#getcompletion#match#do(ctx) abort
  if a:ctx.pos < len(a:ctx.cmdline) &&
        \ (a:ctx.cmdline[a:ctx.pos] !=# '|' &&
        \ a:ctx.cmdline[a:ctx.pos] !=# '"')
    call wildsearch#getcompletion#highlight#do(a:ctx)

    if wildsearch#getcompletion#skip_nonwhitespace(a:ctx) &&
          \ wildsearch#getcompletion#main#skip_whitespace(a:ctx)
      let l:delimiter = a:ctx.cmdline[a:ctx.pos]

      let a:ctx.pos += 1

      call wildsearch#getcompletion#skip_regex#do(a:ctx, l:delimiter)
    endif
  endif

  while a:ctx.pos < len(a:ctx.cmdline) &&
        \ a:ctx.cmdline[a:ctx.pos] !=# '|'
    let a:ctx.pos += 1
  endwhile

  if a:ctx.pos == len(a:ctx.cmdline)
    return
  endif

  let a:ctx.pos += 1
  let a:ctx.cmd = ''

  call wildsearch#getcompletion#main#do(a:ctx)
endfunction
