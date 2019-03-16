let s:opts = wilder#options#get()

function! wilder#render#statusline#draw(chunks) abort
  let l:statusline = ''
  let g:_wilder_xs = map(copy(a:chunks), {_, x -> x[0]})

  let l:i = 0
  while l:i < len(a:chunks)
    let l:statusline .= '%#' . a:chunks[l:i][1] . '#'

    " prevent leading space from being truncated
    if l:i == 0 && g:_wilder_xs[0][0] ==# ' '
      let l:statusline .= ' '
      let g:_wilder_xs[0] = g:_wilder_xs[0][1:]
    endif

    let l:statusline .= '%{g:_wilder_xs[' . string(l:i) . ']}'

    let l:i += 1
  endwhile

  call setwinvar(0, '&statusline', l:statusline)

  redrawstatus
endfunction
