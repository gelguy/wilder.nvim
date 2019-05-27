function! wilder#cmdline#filter#do(ctx) abort
  call wilder#cmdline#skip_vimgrep#do(a:ctx)

  if a:ctx.pos == len(a:ctx.cmdline)
    return
  endif

  if !wilder#cmdline#main#skip_whitespace(a:ctx)
    let a:ctx.expand = 'nothing'
    return
  endif

  let a:ctx.cmd = ''

  call wilder#cmdline#main#do(a:ctx)
endfunction
