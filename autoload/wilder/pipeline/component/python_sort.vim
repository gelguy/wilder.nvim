function! wilder#pipeline#component#python_sort#make() abort
  return {ctx, x -> wilder#pipeline#null(_wilder_python_sort(ctx, x))}
endfunction
