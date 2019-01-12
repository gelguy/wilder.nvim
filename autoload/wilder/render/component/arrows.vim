function! wilder#render#component#arrows#make_previous(args) abort
  let l:state = {
        \ 'previous': get(a:args, 'previous', '< '),
        \ }

  let l:res = {
        \ 'stl': {ctx, xs -> s:left(l:state, ctx, xs)},
        \ 'len': strdisplaywidth(l:state.previous),
        \ }

  if has_key(a:args, 'hl')
    let l:res.hl = a:args.hl
  endif

  return l:res
endfunction

function! wilder#render#component#arrows#make_next(args) abort
  let l:state = {
        \ 'previous': get(a:args, 'previous', '< '),
        \ 'next': get(a:args, 'next', ' >'),
        \ }

  let l:res = {
        \ 'stl': {ctx, xs -> s:right(l:state, ctx, xs)},
        \ 'len': strdisplaywidth(l:state.next),
        \ }

  if has_key(a:args, 'hl')
    let l:res.hl = a:args.hl
  endif

  return l:res
endfunction

function! s:left(state, ctx, xs) abort
  return a:ctx.page[0] > 0 ? a:state.previous : ''
endfunction

function! s:right(state, ctx, xs) abort
  let l:next_page_arrow = a:ctx.page[1] < len(a:xs) - 1 ?
        \ a:state.next :
        \ repeat(' ', strdisplaywidth(a:state.next))

  " add padding if previous arrow is empty
  let l:res = a:ctx.page[0] > 0 ? '' : repeat(' ', strdisplaywidth(a:state.previous))
  let l:res .= l:next_page_arrow
  return l:res
endfunction
