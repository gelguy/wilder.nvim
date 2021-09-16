function! wilder#renderer#component#popupmenu_zip_columns#(f, c1, c2) abort
  let l:state = {
        \ 'c1': a:c1,
        \ 'c2': a:c2,
        \ 'f': a:f,
        \ }

  let l:dynamic = wilder#renderer#is_dynamic_component(a:c1) ||
        \ wilder#renderer#is_dynamic_component(a:c2)

  return {
        \ 'value': {ctx, result -> s:value(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ 'dynamic': l:dynamic,
        \ }
endfunction

function! s:pre_hook(state, ctx) abort
  call wilder#renderer#call_component_pre_hook(a:ctx, a:state.c1)
  call wilder#renderer#call_component_pre_hook(a:ctx, a:state.c2)
endfunction

function! s:post_hook(state, ctx) abort
  call wilder#renderer#call_component_post_hook(a:ctx, a:state.c1)
  call wilder#renderer#call_component_post_hook(a:ctx, a:state.c2)
endfunction

function! s:value(state, ctx, result) abort
  let l:column_lines1 = wilder#renderer#popupmenu#draw_column(a:ctx, a:result, a:state.c1)
  let l:column_lines2 = wilder#renderer#popupmenu#draw_column(a:ctx, a:result, a:state.c2)

  let l:result = []

  let l:ctx = copy(a:ctx)

  let l:i = 0
  while l:i < a:ctx.height
    let l:chunks1 = get(l:column_lines1, l:i, [])
    let l:chunks2 = get(l:column_lines2, l:i, [])
    let l:ctx.i = l:i

    call add(l:result, a:state.f(l:ctx, a:result, l:chunks1, l:chunks2))

    let l:i += 1
  endwhile

  return l:result
endfunction
