function! wildsearch#getcompletion#map#do(ctx) abort
  let l:arg_start = a:ctx.pos

  while a:ctx.pos < len(a:ctx.cmdline)
    let l:arg_start = a:ctx.pos

    call wildsearch#getcompletion#main#skip_nonwhitespace(a:ctx)

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

    call wildsearch#getcompletion#main#skip_whitespace(a:ctx)
  endwhile

  let a:ctx.pos = l:arg_start
endfunction
