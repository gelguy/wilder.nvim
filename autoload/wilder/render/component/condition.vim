function! wilder#render#component#condition#make(predicate, if_true, if_false) abort
  let l:state = {
        \ 'predicate': a:predicate,
        \ 'if_true': a:if_true,
        \ 'if_false': a:if_false,
        \ 'chosen': [],
        \ }

  return {
        \ 'value': {ctx, xs -> s:value(l:state, ctx, xs)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:pre_hook(state, ctx) abort
  call wilder#render#components_pre_hook(a:state.if_true + a:state.if_false, a:ctx)
endfunction

function! s:post_hook(state, ctx) abort
  call wilder#render#components_post_hook(a:state.if_true + a:state.if_false, a:ctx)
endfunction

function! s:value(state, ctx, xs) abort
  let a:state.chosen = a:state.predicate(a:ctx, a:xs) ?
        \ a:state.if_true :
        \ a:state.if_false

  return a:state.chosen
endfunction
