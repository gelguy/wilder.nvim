function! wild#pipeline#component#python_sort#make() abort
  return {ctx, x -> wild#pipeline#null(_wild_python_sort(ctx, x))}
endfunction
