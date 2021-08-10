function! wilder#renderer#redraw(apply_incsearch_fix) abort
  call s:redraw(a:apply_incsearch_fix, 0)
endfunction

function! wilder#renderer#redrawstatus(apply_incsearch_fix) abort
  call s:redraw(a:apply_incsearch_fix, 1)
endfunction

function! s:redraw(apply_incsearch_fix, is_redrawstatus) abort
  if a:apply_incsearch_fix &&
        \ &incsearch &&
        \ (getcmdtype() ==# '/' || getcmdtype() ==# '?')
    call feedkeys(" \<BS>", 'n')
    return
  endif

  if a:is_redrawstatus
    redrawstatus
  else
    redraw
  endif
endfunction
