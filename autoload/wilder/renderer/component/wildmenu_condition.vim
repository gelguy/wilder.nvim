function! wilder#renderer#component#wildmenu_condition#(predicate, if_true, if_false) abort
  let l:state = {
        \ 'predicate': a:predicate,
        \ 'if_true': a:if_true,
        \ 'if_false': a:if_false,
        \ 'chosen': [],
        \ }

  let l:dynamic = wilder#renderer#wildmenu#item_is_dynamic(a:if_true) ||
        \ wilder#renderer#wildmenu#item_is_dynamic(a:if_false)

  return {
        \ 'value': {ctx, result -> s:value(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ 'dynamic': l:dynamic,
        \ }
endfunction

function! s:pre_hook(state, ctx) abort
  call wilder#renderer#wildmenu#item_pre_hook(a:state.if_true, a:ctx)
  call wilder#renderer#wildmenu#item_pre_hook(a:state.if_false, a:ctx)
endfunction

function! s:post_hook(state, ctx) abort
  call wilder#renderer#wildmenu#item_post_hook(a:state.if_true, a:ctx)
  call wilder#renderer#wildmenu#item_post_hook(a:state.if_false, a:ctx)
endfunction

function! s:value(state, ctx, result) abort
  let a:state.chosen = a:state.predicate(a:ctx, a:result)
        \ ? a:state.if_true
        \ : a:state.if_false

  return a:state.chosen
endfunction
