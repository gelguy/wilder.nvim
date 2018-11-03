function! wild#cmdline#highlight#do(ctx) abort
  let l:arg_start = a:ctx.pos

  if !wild#cmdline#main#skip_nonwhitespace(a:ctx)
    let a:ctx.pos = l:arg_start
    return
  endif

  let l:subcommand = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]

  if l:subcommand ==# 'default'
    if !wild#cmdline#main#skip_whitespace(a:ctx)
      return
    endif

    let l:arg_start = a:ctx.pos

    if !wild#cmdline#main#skip_nonwhitespace(a:ctx)
      let a:ctx.pos = l:arg_start
      return
    endif

    let l:subcommand = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]
  endif

  if l:subcommand ==# 'link' || l:subcommand ==# 'clear'
    if !wild#cmdline#main#skip_whitespace(a:ctx)
      return
    endif

    let l:arg_start = a:ctx.pos

    if !wild#cmdline#main#skip_nonwhitespace(a:ctx)
      let a:ctx.pos = l:arg_start
      return
    endif

    if !wild#cmdline#main#skip_whitespace(a:ctx)
      return
    endif

    let l:arg_start = a:ctx.pos

    if !wild#cmdline#main#skip_nonwhitespace(a:ctx)
      let a:ctx.pos = l:arg_start
      return
    endif
  endif

  let a:ctx.pos = l:arg_start
endfunction
