function! wildsearch#pipeline#component#python_search#make(opts)
  return {ctx, x -> wildsearch#pipeline#null(_wildsearch_python_search(a:opts, ctx, x))}
endfunction
