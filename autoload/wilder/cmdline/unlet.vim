function! wilder#cmdline#unlet#do(ctx) abort
  call wilder#cmdline#main#find_last_whitespace(a:ctx)

  if a:ctx.cmdline[a:ctx.pos] ==# '$'
    let a:ctx.expand = 'env_vars'
    let a:ctx.pos += 1
    return
  endif

  let a:ctx.expand = 'var'
endfunction
