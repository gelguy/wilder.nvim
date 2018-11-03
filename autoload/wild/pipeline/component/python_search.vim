function! wild#pipeline#component#python_search#make(opts) abort
  return {ctx, x -> wild#pipeline#null(_wild_python_search(a:opts, ctx, x))}
endfunction
