function! wildsearch#pipeline#component#python_fuzzy_sort#make()
  return {ctx, x -> wildsearch#pipeline#null(_wildsearch_python_fuzzy_sort(ctx, x))}
endfunction
