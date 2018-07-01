function! wildsearch#pipeline#component#python_sort#make(opts)
  return {ctx, x -> wildsearch#pipeline#null(_wildsearch_python_sort(a:opts, ctx, x))}
endfunction
