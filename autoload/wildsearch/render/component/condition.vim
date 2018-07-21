function! wildsearch#render#component#condition#make(predicate, if_true, if_false) abort
  let l:state = {
        \ 'predicate': a:predicate,
        \ 'if_true': a:if_true,
        \ 'if_false': a:if_false,
        \ 'chosen': [],
        \ }

  return {
        \ 'stl': {ctx, x -> s:stl(l:state, ctx, x)},
        \ 'len': {ctx, x -> s:len(l:state, ctx, x)},
        \ 'redraw': {ctx, x -> s:redraw(l:state, ctx, x)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:pre_hook(state, ctx) abort
  call wildsearch#render#components_pre_hook(a:state.if_true + a:state.if_false, a:ctx)
endfunction

function! s:post_hook(state, ctx) abort
  call wildsearch#render#components_post_hook(a:state.if_true + a:state.if_false, a:ctx)
endfunction

function! s:redraw(state, ctx, x) abort
  return wildsearch#render#components_need_redraw(a:state.if_true + a:state.if_false, a:ctx, a:x)
endfunction

function! s:len(state, ctx, candidates) abort
  " choose branch here
  let a:state.chosen = a:state.predicate(a:ctx, a:candidates) ?
        \ a:state.if_true :
        \ a:state.if_false

  return wildsearch#render#components_len(a:state.chosen, a:ctx, a:candidates)
endfunction

function! s:stl(state, ctx, candidates) abort
  return wildsearch#render#components_draw(a:state.chosen, a:ctx, a:candidates)
endfunction
