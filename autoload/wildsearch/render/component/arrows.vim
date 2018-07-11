function! wildsearch#render#component#arrows#make_previous(args)
  let l:res = {
        \ 'stl': {ctx, candidates -> s:left(ctx, candidates)},
        \ 'len': 2,
        \ }

  if has_key(a:args, 'hl')
    let l:res.hl = a:args.hl
  endif

  return l:res
endfunction

function! wildsearch#render#component#arrows#make_next(args)
  let l:res = {
        \ 'stl': {ctx, candidates -> s:right(ctx, candidates)},
        \ 'len': 2,
        \ }

  if has_key(a:args, 'hl')
    let l:res.hl = a:args.hl
  endif

  return l:res
endfunction

function! s:left(ctx, candidates)
  return a:ctx.page[0] > 0 ? '< ' : ''
endfunction

function! s:right(ctx, candidates)
  let l:next_page_arrow = a:ctx.page[1] < len(a:candidates) - 1 ? ' >' : '  '

  let l:res = a:ctx.page[0] > 0 ? '' : '  '
  let l:res .= l:next_page_arrow
  return l:res
endfunction
