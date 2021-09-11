function! wilder#renderer#component#popupmenu_condition#(predicate, if_true, ...) abort
  let l:if_false = get(a:, 1, '')

  let l:state = {
        \ 'predicate': a:predicate,
        \ 'if_true': a:if_true,
        \ 'if_false': l:if_false,
        \ }

  let l:dynamic = wilder#renderer#is_dynamic_component(a:if_true) ||
        \ wilder#renderer#is_dynamic_component(l:if_false)

  return {
        \ 'value': {ctx, result -> s:value(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ 'dynamic': l:dynamic,
        \ }
endfunction

function! s:pre_hook(state, ctx) abort
  call wilder#renderer#call_component_pre_hook(a:ctx, a:state.if_true)
  call wilder#renderer#call_component_pre_hook(a:ctx, a:state.if_false)
endfunction

function! s:post_hook(state, ctx) abort
  call wilder#renderer#call_component_post_hook(a:ctx, a:state.if_true)
  call wilder#renderer#call_component_post_hook(a:ctx, a:state.if_false)
endfunction

function! s:value(state, ctx, result) abort
  let l:Column = a:state.predicate(a:ctx, a:result) ?
        \ a:state.if_true :
        \ a:state.if_false

  return wilder#renderer#popupmenu#draw_column(a:ctx, a:result, l:Column)
endfunction
