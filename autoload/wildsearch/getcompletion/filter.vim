function! wildsearch#getcompletion#filter#do(ctx) abort
  call wildsearch#getcompletion#skip_vimgrep#do(a:ctx)

  if a:ctx.pos == len(a:ctx.cmdline)
    return
  endif

  if !wildsearch#getcompletion#skip_whitespace(a:ctx)
    return
  endif

  let a:ctx.cmd = ''

  call wildsearch#getcompletion#main#do(a:ctx)
endfunction
