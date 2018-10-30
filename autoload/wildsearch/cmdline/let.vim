function! wildsearch#cmdline#let#do(ctx)
  if a:ctx.cmd ==# 'let' &&
        \ match(a:ctx.cmdline[a:ctx.pos :], '[' . "'" . '"+\-*/%.=!?~|&$([<>,#]') == -1
    " let var1 var2 ...
    let l:arg_start = a:ctx.pos

    while a:ctx.pos < len(a:ctx.cmdline)
      if wildsearch#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
        let l:arg_start = a:ctx.pos + 1
      endif

      let a:ctx.pos += 1
    endwhile

    let a:ctx.pos = l:arg_start

    return
  endif

  let l:expand_type = a:ctx.cmd ==# 'call' ? 'func' : 'expr'
  let l:got_eq = 0

  let l:arg_start = a:ctx.pos

  while a:ctx.pos < len(a:ctx.cmdline)
    let l:char = a:ctx.cmdline[a:ctx.pos]

    if match(l:char, '[' . "'" . '"+\-*/%.=!?~|&$([<>,#]') != -1
      if l:char ==# '&' && a:ctx.pos < len(a:ctx.cmdline)
        if a:ctx.cmdline[a:ctx.pos + 1] ==# '&'
          let a:ctx.pos += 1
          let l:expand_type = a:ctx.cmd ==# 'let' || l:got_eq ?
                \ 'expr' :
                \ 'nothing'
        elseif l:char !=# ' '
          let l:expand_type = 'settings'
          if a:ctx.pos + 2 < len(a:ctx.cmdline) &&
                \ (a:ctx.cmdline[a:ctx.pos + 1] ==# 'l' ||
                \ a:ctx.cmdline[a:ctx.pos + 2] ==# 'g') &&
                \ a:ctx.cmdline[a:ctx.pos + 2] ==# ':'
            let a:ctx.pos += 2
          endif
        endif
      elseif l:char ==# '$'
        let l:expand_type = 'env_var'
      elseif l:char ==# '='
        let l:got_eq = 1
        let l:expand_type = 'expr'
      elseif l:char ==# '#' && l:expand_type ==# 'expr'
        " this doesn't look correct
        " but we follow the wildmenu implementation
        break
      elseif (l:char ==# '<' || l:char ==# '#') &&
            \ l:expand_type ==# 'func' &&
            \ stridx(a:ctx.cmdline[a:ctx.pos + 1 :], '(') == -1
        " this doesn't look correct either
        break
      elseif a:ctx.cmd !=# 'let' || l:got_eq
        " this doesn't look correct either
        if l:char ==# '"'
          let a:ctx.pos += 1

          while a:ctx.pos < len(a:ctx.cmdline)
                \ && a:ctx.cmdline[a:ctx.pos] !=# '"'
            if a:ctx.pos + 1 < len(a:ctx.cmdline) &&
                  \ a:ctx.cmdline[a:ctx.pos] ==# '\'
              let a:ctx.pos += 1
            endif

            let a:ctx.pos += 1
          endwhile

          let l:expand_type = 'nothing'
        elseif l:char ==# "'"
          while a:ctx.pos < len(a:ctx.cmdline)
            if a:ctx.cmdline[a:ctx.pos] ==# "'" &&
                  \ a:ctx.pos + 1 < len(a:ctx.cmdline) &&
                  \ a:ctx.cmdline[a:ctx.pos + 1] ==# "'"
              let a:ctx.pos += 1
            else
              break
            endif

            let a:ctx.pos += 1
          endwhile

          let l:expand_type = 'nothing'
        elseif l:char ==# '|'
          if a:ctx.pos + 1 < len(a:ctx.cmdline) &&
                \ a:ctx.cmdline[a:ctx.pos + 1] ==# '|'
            let a:ctx.pos += 1
            let l:expand_type = 'expr'
          else
            let l:expand_type = 'command'
          endif
        else
          let l:expand_type = 'expr'
        endif
      else
        let l:expand_type = 'expr'
      endif

      let l:arg_start = a:ctx.pos + 1
    endif

    let a:ctx.pos += 1

    if wildsearch#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
      if !wildsearch#cmdline#main#skip_whitespace(a:ctx)
        let l:arg_start = a:ctx.pos
        break
      endif

      let l:arg_start = a:ctx.pos
    endif
  endwhile

  let a:ctx.pos = l:arg_start
endfunction
