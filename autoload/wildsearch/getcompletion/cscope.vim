function! wildsearch#getcompletion#cscope#do(ctx) abort
  let l:arg_start = a:ctx.pos

  if !wildsearch#getcompletion#main#skip_nonwhitespace(a:ctx)
    let a:ctx.pos = l:arg_start
    return
  endif

  call wildsearch#getcompletion#main#skip_whitespace(a:ctx)
endfunction
