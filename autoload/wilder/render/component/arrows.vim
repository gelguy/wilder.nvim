function! wilder#render#component#arrows#make_previous(args) abort
  let l:previous = get(a:args, 'previous', '< ')

  return {
        \ 'value': {ctx, xs -> s:left(l:previous, ctx, xs)},
        \ 'len': strdisplaywidth(l:previous),
        \ 'hl': get(a:args, 'hl', '')
        \ }
endfunction

function! wilder#render#component#arrows#make_next(args) abort
  let l:previous = get(a:args, 'previous', '< ')
  let l:next = get(a:args, 'next', '< ')

  return {
        \ 'value': {ctx, xs -> s:right(l:previous, l:next, ctx, xs)},
        \ 'len': strdisplaywidth(l:next),
        \ }
endfunction

function! s:left(previous, ctx, xs) abort
  return a:ctx.page[0] > 0 ? a:previous : ''
endfunction

function! s:right(previous, next, ctx, xs) abort
  let l:next_page_arrow = a:ctx.page[1] < len(a:xs) - 1 ?
        \ a:next :
        \ repeat(' ', strdisplaywidth(a:next))

  " add padding if previous arrow is empty
  let l:res = a:ctx.page[0] > 0 ? '' : repeat(' ', strdisplaywidth(a:previous))
  let l:res .= l:next_page_arrow

  return l:res
endfunction
