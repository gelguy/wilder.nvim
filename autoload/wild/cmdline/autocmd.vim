function! wild#cmdline#autocmd#do(ctx) abort
  let l:group = ''

  " check for group name
  let l:arg_start = a:ctx.pos
  let l:in_group = 1
  while a:ctx.pos < len(a:ctx.cmdline)
    if wild#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos]) ||
          \ a:ctx.cmdline[a:ctx.pos] ==# '|'
      let l:in_group = 0
      break
    endif

    let a:ctx.pos += 1
  endwhile

  " complete the group name
  if l:in_group
    let a:ctx.pos = l:arg_start

    return
  endif

  " group name does not exist
  " move cursor back to front and assume there is no group argument
  let l:group_name = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]
  if !exists('#' . l:group_name)
    let a:ctx.pos = l:arg_start
    " else move cursor to start of next arg
  else
    call wild#cmdline#main#skip_whitespace(a:ctx)
    let l:arg_start = a:ctx.pos
  endif

  " handle event name
  let l:arg_start = a:ctx.pos
  while a:ctx.pos < len(a:ctx.cmdline) &&
        \ !wild#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
    " handle ,
    if a:ctx.cmdline[a:ctx.pos] ==# ','
      let l:arg_start = a:ctx.pos + 1
    endif

    let a:ctx.pos += 1
  endwhile

  " complete event/group name
  if a:ctx.pos == len(a:ctx.cmdline)
    let a:ctx.pos = l:arg_start
    return
  endif

  if !wild#cmdline#main#skip_whitespace(a:ctx)
    return
  endif

  " handle pattern
  while a:ctx.pos < len(a:ctx.cmdline) &&
        \ !wild#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
    if a:ctx.cmdline[a:ctx.pos] ==# '\' &&
          \ a:ctx.pos + 1 < len(a:ctx.cmdline)
      let a:ctx.pos += 1
    endif

    let a:ctx.pos += 1
  endwhile

  " new command
  if a:ctx.pos + 1 < len(a:ctx.cmdline)
    let a:ctx.pos += 1
    let a:ctx.cmd = ''

    call wild#cmdline#main#do(a:ctx)
    return
  endif
endfunction
