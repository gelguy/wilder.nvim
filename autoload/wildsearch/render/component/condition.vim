function! wildsearch#render#component#condition#make(predicate, if_true, if_false)
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
        \ 'on_start': {ctx -> s:on_start(l:state, ctx)},
        \ 'on_end': {ctx -> s:on_end(l:state, ctx)},
        \ }
endfunction

function! s:on_start(state, ctx)
  call wildsearch#render#components_on_start(a:state.if_true + a:state.if_false, a:ctx)
endfunction

function! s:on_end(state, ctx)
  call wildsearch#render#components_on_end(a:state.if_true + a:state.if_false, a:ctx)
endfunction

function! s:redraw(state, ctx, x)
  return wildsearch#render#components_need_redraw(a:state.if_true + a:state.if_false, a:ctx, a:x)
endfunction

function! s:len(state, ctx, candidates)
  " choose branch here
  let a:state.chosen = a:state.predicate(a:ctx, a:candidates) ?
        \ a:state.if_true :
        \ a:state.if_false

  return wildsearch#render#components_len(a:state.chosen, a:ctx, a:candidates)
endfunction

function! s:stl(state, ctx, candidates)
  return wildsearch#render#components_draw(a:state.chosen, a:ctx, a:candidates)
endfunction
