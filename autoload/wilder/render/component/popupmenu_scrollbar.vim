function! wilder#render#component#popupmenu_scrollbar#make(args) abort
  let l:args = extend(copy(a:args), {
        \ 'thumb': '█',
        \ 'bar': ' ',
        \ }, 'keep')

  let l:width = strdisplaywidth(l:args.thumb)

  return {
        \ 'decorate': {ctx, lines -> s:decorate(a:args, ctx, lines)},
        \ 'space_used': [0, l:width, 0, 0],
        \ }
endfunction

function! s:decorate(args, ctx, lines) abort
  if empty(a:lines)
    return a:lines
  endif

  let l:selected = a:ctx.selected - a:ctx.page[0]


  return l:lines
endfunction

