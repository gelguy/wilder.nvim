function! wilder#cmdline#autocmd#do(ctx, doautocmd) abort
  let l:group = ''

  " check for group name
  let l:arg_start = a:ctx.pos
  let l:in_group = 1
  while a:ctx.pos < len(a:ctx.cmdline)
    if wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos]) ||
          \ a:ctx.cmdline[a:ctx.pos] ==# '|'
      let l:in_group = 0
      break
    endif

    let a:ctx.pos += 1
  endwhile

  " group name does not exist
  " move cursor back to front and assume there is no group argument
  let l:group_name = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]
  if !exists('#' . l:group_name)
    let a:ctx.pos = l:arg_start
  else
    " else move cursor to start of next arg
    call wilder#cmdline#main#skip_whitespace(a:ctx)
  endif

  " handle event name
  let l:arg_start = a:ctx.pos
  while a:ctx.pos < len(a:ctx.cmdline) &&
        \ !wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
    " handle ,
    if a:ctx.cmdline[a:ctx.pos] ==# ','
      let l:arg_start = a:ctx.pos + 1
    endif

    let a:ctx.pos += 1
  endwhile

  " complete event/group name
  if a:ctx.pos == len(a:ctx.cmdline)
    let a:ctx.expand = 'event'
    let a:ctx.pos = l:arg_start
    return
  endif

  call wilder#cmdline#main#skip_whitespace(a:ctx)

  " handle pattern
  let l:arg_start = a:ctx.pos
  while a:ctx.pos < len(a:ctx.cmdline) &&
        \ !wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
    if a:ctx.cmdline[a:ctx.pos] ==# '\' &&
          \ a:ctx.pos + 1 < len(a:ctx.cmdline)
      let a:ctx.pos += 1
    endif

    let a:ctx.pos += 1
  endwhile

  " new command
  if a:ctx.pos < len(a:ctx.cmdline)
    let a:ctx.pos += 1
    let a:ctx.cmd = ''

    call wilder#cmdline#main#do(a:ctx)
    return
  endif

  if a:doautocmd
    let a:ctx.expand = 'file'
    let a:ctx.pos =  l:arg_start
  endif
endfunction
