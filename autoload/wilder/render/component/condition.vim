function! wilder#render#component#condition#make(predicate, if_true, if_false) abort
  let l:state = {
        \ 'predicate': a:predicate,
        \ 'if_true': a:if_true,
        \ 'if_false': a:if_false,
        \ 'chosen': [],
        \ }

  return {
        \ 'value': {ctx, x -> s:value(l:state, ctx, x)},
        \ 'len': {ctx, x -> s:len(l:state, ctx, x)},
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

function! s:len(state, ctx, xs) abort
  " choose branch here
  let a:state.chosen = a:state.predicate(a:ctx, a:xs) ?
        \ a:state.if_true :
        \ a:state.if_false

  return wilder#render#components_len(a:state.chosen, a:ctx, a:xs)
endfunction

function! s:value(state, ctx, xs) abort
  return wilder#render#components_draw(a:state.chosen, a:ctx, a:xs)
endfunction
