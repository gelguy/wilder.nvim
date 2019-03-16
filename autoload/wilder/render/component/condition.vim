function! wilder#render#component#condition#make(predicate, if_true, if_false) abort
  let l:state = {
        \ 'predicate': a:predicate,
        \ 'if_true': a:if_true,
        \ 'if_false': a:if_false,
        \ 'chosen': [],
        \ }

  return {
        \ 'value': {ctx, x -> s:value(l:state, ctx, x)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:pre_hook(state, ctx) abort
  for l:Component in a:state.if_true + a:state.if_false
    if type(l:Component) == v:t_dict && has_key(l:Component, 'pre_hook')
      call l:Component.pre_hook(a:ctx)
    endif
  endfor
endfunction

function! s:post_hook(state, ctx) abort
  for l:Component in a:state.if_true + a:state.if_false
    if type(l:Component) == v:t_dict && has_key(l:Component, 'post_hook')
      call l:Component.post_hook(a:ctx)
    endif
  endfor
endfunction

function! s:value(state, ctx, xs) abort
  let a:state.chosen = a:state.predicate(a:ctx, a:xs) ?
        \ a:state.if_true :
        \ a:state.if_false

  return a:state.chosen
endfunction
