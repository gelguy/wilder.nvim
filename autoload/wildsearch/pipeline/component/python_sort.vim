function! wildsearch#pipeline#component#python_sort#make() abort
  return {ctx, x -> wildsearch#pipeline#null(_wildsearch_python_sort(ctx, x))}
endfunction
