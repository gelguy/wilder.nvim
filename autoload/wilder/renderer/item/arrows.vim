function! wilder#renderer#item#arrows#make_previous(args) abort
  let l:previous = get(a:args, 'previous', '< ')

  return {
        \ 'value': {ctx, result -> s:left(l:previous, ctx, result)},
        \ 'len': strdisplaywidth(l:previous),
        \ 'hl': get(a:args, 'hl', '')
        \ }
endfunction

function! wilder#renderer#item#arrows#make_next(args) abort
  let l:previous = get(a:args, 'previous', '< ')
  let l:next = get(a:args, 'next', ' >')

  return {
        \ 'value': {ctx, result -> s:right(l:previous, l:next, ctx, result)},
        \ 'len': strdisplaywidth(l:next),
        \ }
endfunction

function! s:left(previous, ctx, result) abort
  return a:ctx.page[0] > 0 ? a:previous : ''
endfunction

function! s:right(previous, next, ctx, result) abort
  let l:next_page_arrow = a:ctx.page[1] < len(a:result.value) - 1
        \ ? a:next
        \ : repeat(' ', strdisplaywidth(a:next))

  " add padding if previous arrow is empty
  let l:res = a:ctx.page[0] > 0
        \ ? ''
        \ : repeat(' ', strdisplaywidth(a:previous))
  let l:res .= l:next_page_arrow

  return l:res
endfunction
