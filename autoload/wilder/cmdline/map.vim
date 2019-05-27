function! wilder#cmdline#map#do(ctx, force) abort
  if a:force && a:ctx.cmd !=# 'map' && a:ctx.cmd !=# 'unmap'
    let a:ctx.expand = 'nothing'
    return
  endif

  let a:ctx.expand = 'mapping'
  let l:arg_start = a:ctx.pos

  while a:ctx.pos < len(a:ctx.cmdline)
    let l:arg_start = a:ctx.pos

    call wilder#cmdline#main#skip_nonwhitespace(a:ctx)

    if a:ctx.pos == len(a:ctx.cmdline)
      let a:ctx.pos = l:arg_start
      return
    endif

    let l:arg = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]

    if l:arg !=# '<buffer>' &&
          \ l:arg !=# '<unique>' &&
          \ l:arg !=# '<nowait>' &&
          \ l:arg !=# '<silent>' &&
          \ l:arg !=# '<special>' &&
          \ l:arg !=# '<script>' &&
          \ l:arg !=# '<expr>'
      let a:ctx.pos = l:arg_start
      return
    endif

    call wilder#cmdline#main#skip_whitespace(a:ctx)
  endwhile

  let a:ctx.pos = l:arg_start
endfunction
