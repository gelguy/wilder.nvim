function! wildsearch#render#component#arrows#make_previous(args)
  let l:res = {
        \ 'f': {ctx, candidates -> s:left(ctx, candidates)},
        \ 'len': 2,
        \ }

  if has_key(a:args, 'hl')
    let l:res.hl = a:args.hl
  endif

  return l:res
endfunction

function! wildsearch#render#component#arrows#make_next(args)
  let l:res = {
        \ 'f': {ctx, candidates -> s:right(ctx, candidates)},
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
  let l:width_needed = a:ctx.page[0] > 0 ? 2 : 4
  return repeat(' ', l:width_needed - 2) . l:next_page_arrow
endfunction
