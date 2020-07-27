function! wilder#render#component#popupmenu_padding#make(args) abort
  let l:args = extend(copy(a:args), {
        \ 'left': 0,
        \ 'right': 0,
        \ 'top': 0,
        \ 'bottom': 0,
        \ }, 'keep')

  return {
        \ 'decorate': {ctx, lines -> s:decorate(a:args, ctx, lines)},
        \ 'space_used': [l:args.left, l:args.right, l:args.top, l:args.bottom],
        \ }
endfunction

function! s:decorate(args, ctx, lines) abort
  if empty(a:lines)
    return a:lines
  endif

  let l:selected = a:ctx.selected - a:ctx.page[0]

  if a:args.left || a:args.right
    let l:lines = map(a:lines, {i, line ->
          \ [[repeat(' ', a:args.left), a:ctx.highlights[l:selected == i ? 'selected' : 'default']]] +
          \ line +
          \ [[repeat(' ', a:args.right), a:ctx.highlights[l:selected == i ? 'selected' : 'default']]]})
  endif

  if a:args.top || a:args.bottom
    let l:width = wilder#render#chunks_displaywidth(l:lines[0])

    let l:padding_line = [[repeat(' ', l:width), a:ctx.highlights.default]]
    let l:lines = repeat(l:padding_line, a:args.top)
          \ l:lines +
          \ repeat(l:padding_line, a:args.bottom)
  endif

  return l:lines
endfunction
