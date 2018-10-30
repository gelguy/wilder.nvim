function! wildsearch#cmdline#syntax#do(ctx) abort
  " get subcommand
  let l:arg_start = a:ctx.pos
  let l:in_subcommand = 1
  while a:ctx.pos < len(a:ctx.cmdline)
    if wildsearch#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
      let l:in_subcommand = 0
      break
    endif

    let a:ctx.pos += 1
  endwhile

  if l:in_subcommand
    return
  endif

  let l:subcommand = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]
  echom l:subcommand . '1'

  " invalid match
  if l:subcommand !=# 'case' &&
        \ l:subcommand !=# 'spell' &&
        \ l:subcommand !=# 'sync' &&
        \ l:subcommand !=# 'keyword' &&
        \ l:subcommand !=# 'region' &&
        \ l:subcommand !=# 'match' &&
        \ l:subcommand !=# 'list'
    let a:ctx.pos = len(a:ctx.cmdline)
  endif

  call wildsearch#cmdline#main#skip_whitespace(a:ctx)
endfunction
