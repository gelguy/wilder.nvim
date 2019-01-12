function! wilder#cmdline#cscope#do(ctx) abort
  let l:arg_start = a:ctx.pos

  if !wilder#cmdline#main#skip_nonwhitespace(a:ctx)
    let a:ctx.pos = l:arg_start
    return
  endif

  call wilder#cmdline#main#skip_whitespace(a:ctx)
endfunction
