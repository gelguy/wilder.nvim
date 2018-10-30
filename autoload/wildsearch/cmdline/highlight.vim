function! wildsearch#cmdline#highlight#do(ctx) abort
  let l:arg_start = a:ctx.pos

  if !wildsearch#cmdline#main#skip_nonwhitespace(a:ctx)
    let a:ctx.pos = l:arg_start
    return
  endif

  let l:subcommand = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]

  if l:subcommand ==# 'default'
    if !wildsearch#cmdline#main#skip_whitespace(a:ctx)
      return
    endif

    let l:arg_start = a:ctx.pos

    if !wildsearch#cmdline#main#skip_nonwhitespace(a:ctx)
      let a:ctx.pos = l:arg_start
      return
    endif

    let l:subcommand = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]
  endif

  if l:subcommand ==# 'link' || l:subcommand ==# 'clear'
    if !wildsearch#cmdline#main#skip_whitespace(a:ctx)
      return
    endif

    let l:arg_start = a:ctx.pos

    if !wildsearch#cmdline#main#skip_nonwhitespace(a:ctx)
      let a:ctx.pos = l:arg_start
      return
    endif

    if !wildsearch#cmdline#main#skip_whitespace(a:ctx)
      return
    endif

    let l:arg_start = a:ctx.pos

    if !wildsearch#cmdline#main#skip_nonwhitespace(a:ctx)
      let a:ctx.pos = l:arg_start
      return
    endif
  endif

  let a:ctx.pos = l:arg_start
endfunction
