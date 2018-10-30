function! wildsearch#cmdline#match#do(ctx) abort
  if a:ctx.pos < len(a:ctx.cmdline) &&
        \ (a:ctx.cmdline[a:ctx.pos] !=# '|' &&
        \ a:ctx.cmdline[a:ctx.pos] !=# '"')
    call wildsearch#cmdline#highlight#do(a:ctx)

    if wildsearch#cmdline#main#skip_nonwhitespace(a:ctx) &&
          \ wildsearch#cmdline#main#skip_whitespace(a:ctx)
      let l:delimiter = a:ctx.cmdline[a:ctx.pos]

      let a:ctx.pos += 1

      call wildsearch#cmdline#skip_regex#do(a:ctx, l:delimiter)
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

  call wildsearch#cmdline#main#do(a:ctx)
endfunction
