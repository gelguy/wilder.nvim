function! wilder#renderer#wildmenu_item#index#make(args) abort
  return {
        \ 'value': {ctx, result -> s:value(a:args, ctx, result)},
        \ 'len': {ctx, result -> len(len(result.value)) * 2 + 1 + 2},
        \ 'hl': get(a:args, 'hl', ''),
        \ }
endfunction

function! s:value(args, ctx, result) abort
  let l:total = len(a:result.value) == 0 ? '-' : len(a:result.value)
  let l:displaywidth = len(l:total)
  let l:selected = a:ctx.selected == -1 ? '-' : a:ctx.selected + 1

  let l:result = ' '
  let l:result .= repeat(' ', l:displaywidth - len(l:selected)) . l:selected
  let l:result .= '/' . l:total
  let l:result .= ' '

  return l:result
endfunction
