function! wilder#pipeline#component#python_search#make(opts) abort
  return {ctx, x -> wilder#pipeline#null(_wilder_python_search(a:opts, ctx, x))}
endfunction
