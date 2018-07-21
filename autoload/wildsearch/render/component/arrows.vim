function! wildsearch#render#component#arrows#make_previous(args) abort
  let l:state = {
        \ 'previous': get(a:args, 'previous', '< '),
        \ }

  let l:res = {
        \ 'stl': {ctx, candidates -> s:left(l:state, ctx, candidates)},
        \ 'len': strdisplaywidth(l:state.previous),
        \ }

  if has_key(a:args, 'hl')
    let l:res.hl = a:args.hl
  endif

  return l:res
endfunction

function! wildsearch#render#component#arrows#make_next(args) abort
  let l:state = {
        \ 'previous': get(a:args, 'previous', '< '),
        \ 'next': get(a:args, 'next', ' >'),
        \ }

  let l:res = {
        \ 'stl': {ctx, candidates -> s:right(l:state, ctx, candidates)},
        \ 'len': strdisplaywidth(l:state.next),
        \ }

  if has_key(a:args, 'hl')
    let l:res.hl = a:args.hl
  endif

  return l:res
endfunction

function! s:left(state, ctx, candidates) abort
  return a:ctx.page[0] > 0 ? a:state.previous : ''
endfunction

function! s:right(state, ctx, candidates) abort
  let l:next_page_arrow = a:ctx.page[1] < len(a:candidates) - 1 ?
        \ a:state.next :
        \ repeat(' ', strdisplaywidth(a:state.next))

  " add padding if previous arrow is empty
  let l:res = a:ctx.page[0] > 0 ? '' : repeat(' ', strdisplaywidth(a:state.previous))
  let l:res .= l:next_page_arrow
  return l:res
endfunction
