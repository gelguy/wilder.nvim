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
        \ 'init': {ctx -> s:init(l:args, ctx)},
        \ }
endfunction

function! s:init(args, ctx)
  call wildsearch#render#init_components(a:args.if_true + a:args.if_false, a:ctx)
endfunction

function! s:redraw(args, ctx, x)
  return wildsearch#render#need_redraw(a:args.if_true + a:args.if_false, a:ctx, a:x)
endfunction

function! s:len(args, ctx, candidates)
  " choose branch here
  let a:args.chosen = a:args.predicate(a:ctx, a:candidates) ?
        \ a:args.if_true :
        \ a:args.if_false

  return wildsearch#render#len(a:args.chosen, a:ctx, a:candidates)
endfunction

function! s:stl(args, ctx, candidates)
  return wildsearch#render#draw_components(a:args.chosen, a:ctx, a:candidates)
endfunction
