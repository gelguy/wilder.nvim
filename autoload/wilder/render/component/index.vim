function! wilder#render#component#index#make(args) abort
  return {
        \ 'value': {ctx, result -> s:value(a:args, ctx, result)},
        \ 'len': {ctx, result -> len(len(result.xs)) * 2 + 1 + 2},
        \ 'hl': get(a:args, 'hl', ''),
        \ }
endfunction

function! s:value(args, ctx, result) abort
  let l:num_xs = len(a:result.xs) == 0 ? '-' : len(a:result.xs)
  let l:displaywidth = len(l:num_xs)
  let l:selected = a:ctx.selected == -1 ? '-' : a:ctx.selected + 1

  let l:result = ' '
  let l:result .= repeat(' ', l:displaywidth - len(l:selected)) . l:selected
  let l:result .= '/' . l:num_xs
  let l:result .= ' '

  return l:result
endfunction
