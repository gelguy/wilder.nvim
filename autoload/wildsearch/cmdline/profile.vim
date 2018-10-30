function! wildsearch#cmdline#profile#do(ctx) abort
  let l:arg_start = a:ctx.pos

  if !wildsearch#cmdline#main#skip_nonwhitespace(a:ctx)
    let a:ctx.pos = l:arg_start
    return
  endif

  let l:subcommand = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]

  if l:subcommand ==# 'start'
    call wildsearch#cmdline#main#skip_whitespace(a:ctx)
  endif
endfunction
