function! wildsearch#cmdline#filter#do(ctx) abort
  call wildsearch#cmdline#skip_vimgrep#do(a:ctx)

  if a:ctx.pos == len(a:ctx.cmdline)
    return
  endif

  if !wildsearch#cmdline#main#skip_whitespace(a:ctx)
    return
  endif

  let a:ctx.cmd = ''

  call wildsearch#cmdline#main#do(a:ctx)
endfunction
