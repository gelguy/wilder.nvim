function! wilder#pipeline#component#result_fmap#make(f) abort
  return {ctx, result -> s:result_fmap(a:f, ctx, result)}
endfunction

function! s:result_fmap(f, ctx, result) abort
  let l:result = type(a:result) isnot v:t_dict ?
        \ {'xs': a:result} :
        \ a:result

  return wilder#wait(a:f(a:ctx, l:result.xs),
        \ {ctx, xs -> wilder#resolve(ctx,
        \   extend(l:result, type(xs) is v:t_dict ? xs : {'xs': xs}))})
endfunction
