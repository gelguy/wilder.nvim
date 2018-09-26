function! wildsearch#getcompletion#substitute#do(ctx) abort
  " treat whole /{from}/{to}/{flags} as argument

  if a:ctx.pos >= len(a:ctx.cmdline)
    return
  endif

  let l:delimiter = a:ctx.cmdline[a:ctx.pos]
  let l:arg_start = a:ctx.pos
  let a:ctx.pos += 1

  " delimiter not reached
  if wildsearch#getcompletion#skip_regex#do(a:ctx, l:delimiter)
    let a:ctx.pos = l:arg_start
    return
  endif

  " skip delimiter
  let a:ctx.pos += 1

  let l:delimiter_reached = 0

  while a:ctx.pos < len(a:ctx.cmdline)
    if a:ctx.cmdline[a:ctx.pos] ==# '\' &&
          \ a:ctx.pos + 1 < len(a:ctx.cmdline)
      let a:ctx.pos += 1
    elseif a:ctx.cmdline[a:ctx.pos] ==# l:delimiter
      let l:delimiter_reached = 1

      break
    endif

    let a:ctx.pos += 1
  endwhile

  if !l:delimiter_reached
    let a:ctx.pos = l:arg_start
    return
  endif

  " skip delimiter
  let a:ctx.pos += 1

  " consume until | or " is reached
  while a:ctx.pos < len(a:ctx.cmdline)
    if a:ctx.cmdline[a:ctx.pos] ==# '"'
      let a:ctx.pos = len(a:ctx.cmdline)

      return
    elseif a:ctx.cmdline[a:ctx.pos] ==# '|'
      let a:ctx.cmd = ''

      call wildsearch#getcompletion#main#do(a:ctx)
      return
    endif

    let a:ctx.pos += 1
  endwhile

  let a:ctx.pos = l:arg_start

  return
endfunction
