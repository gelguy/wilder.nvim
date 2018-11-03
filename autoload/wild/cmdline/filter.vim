function! wild#cmdline#filter#do(ctx) abort
  call wild#cmdline#skip_vimgrep#do(a:ctx)

  if a:ctx.pos == len(a:ctx.cmdline)
    return
  endif

  if !wild#cmdline#main#skip_whitespace(a:ctx)
    return
  endif

  let a:ctx.cmd = ''

  call wild#cmdline#main#do(a:ctx)
endfunction
