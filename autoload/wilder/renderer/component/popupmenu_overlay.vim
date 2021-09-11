function! wilder#renderer#component#popupmenu_overlay#(...) abort
  if empty(a:000)
    return ''
  endif

  let l:state = {
        \ 'columns': a:000,
        \ }

  let l:dynamic = 0
  for l:Column in a:000
    if wilder#renderer#is_dynamic_component(l:Column)
      let l:dynamic = 1
      break
    endif
  endfor

  return {
        \ 'value': {ctx, result -> s:value(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ 'dynamic': l:dynamic,
        \ }
endfunction

function! s:pre_hook(state, ctx) abort
  for l:Column in a:state.columns
    call wilder#renderer#call_component_pre_hook(a:ctx, l:Column)
  endfor
endfunction

function! s:post_hook(state, ctx) abort
  for l:Column in a:state.columns
    call wilder#renderer#call_component_post_hook(a:ctx, l:Column)
  endfor
endfunction

function! s:value(state, ctx, result) abort
  let l:column_lines = map(copy(a:state.columns),
        \ {_, column -> wilder#renderer#popupmenu#draw_column(a:ctx, a:result, column)})

  let l:result = []

  let l:i = 0
  while l:i < a:ctx.height
    call add(l:result, s:get_first_non_empty_column(l:column_lines, l:i))

    let l:i += 1
  endwhile

  return l:result
endfunction

function! s:get_first_non_empty_column(column_lines, i) abort
  for l:column_line in a:column_lines
    if len(l:column_line) < a:i
      continue
    endif

    let l:line = l:column_line[a:i]
    if s:is_non_empty_line(l:line)
      return l:line
    endif
  endfor

  return get(a:column_lines[0], a:i, [])
endfunction

function! s:is_non_empty_line(line) abort
  for l:chunk in a:line
    if l:chunk[0] =~# '\S'
      return 1
    endif
  endfor

  return 0
endfunction
