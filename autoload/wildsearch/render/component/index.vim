function! wildsearch#render#component#index#make(args)
  let l:res = {
        \ 'f': {ctx, candidates -> s:f(a:args, ctx, candidates)},
        \ 'len': {_, candidates -> len(len(candidates)) * 2 + 1 + 2},
        \ }

  if has_key(a:args, 'hl')
    let l:res.hl = a:args.hl
  endif

  return l:res
endfunction

function! s:f(args, ctx, candidates)
  let l:num_candidates = len(a:candidates) == 0 ? '-' : len(a:candidates)
  let l:displaywidth = len(l:num_candidates)
  let l:selected = a:ctx.selected == -1 ? '-' : a:ctx.selected + 1

  let l:result = ' '
  let l:result .= repeat(' ', l:displaywidth - len(l:selected)) . l:selected
  let l:result .= '/' . l:num_candidates
  let l:result .= ' '

  return l:result
endfunction
