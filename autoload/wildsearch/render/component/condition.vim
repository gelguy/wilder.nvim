function! wildsearch#render#component#condition#make(predicate, if_true, if_false)
  let l:args = {
        \ 'predicate': a:predicate,
        \ 'if_true': a:if_true,
        \ 'if_false': a:if_false,
        \ 'chosen': [],
        \ }

  return {
        \ 'stl': {ctx, x -> s:stl(l:args, ctx, x)},
        \ 'len': {ctx, x -> s:len(l:args, ctx, x)},
        \ 'redraw': {ctx, x -> s:redraw(l:args, ctx, x)},
        \ 'on_start': {ctx -> s:on_start(l:args, ctx)},
        \ }
endfunction

function! s:on_start(args, ctx)
  call wildsearch#render#components_on_start(a:args.if_true + a:args.if_false, a:ctx)
endfunction

function! s:redraw(args, ctx, x)
  return wildsearch#render#components_need_redraw(a:args.if_true + a:args.if_false, a:ctx, a:x)
endfunction

function! s:len(args, ctx, candidates)
  " choose branch here
  let a:args.chosen = a:args.predicate(a:ctx, a:candidates) ?
        \ a:args.if_true :
        \ a:args.if_false

  return wildsearch#render#components_len(a:args.chosen, a:ctx, a:candidates)
endfunction

function! s:stl(args, ctx, candidates)
  return wildsearch#render#components_draw(a:args.chosen, a:ctx, a:candidates)
endfunction
