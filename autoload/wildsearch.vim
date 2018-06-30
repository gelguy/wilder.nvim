function! wildsearch#sleep(t)
  return {ctx, x -> wildsearch#pipeline#null(_wildsearch_python_sleep(a:t, ctx, x))}
endfunction

function! wildsearch#branch(...)
  return wildsearch#pipeline#component#branch#make(a:000)
endfunction

function! wildsearch#python_search(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#pipeline#component#python_search#make(l:args)
endfunction

function! wildsearch#vim_search(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#pipeline#component#vim_search#make(l:args)
endfunction

function! wildsearch#python_uniq()
  return {ctx, x -> wildsearch#pipeline#null(_wildsearch_python_uniq(ctx, x))}
endfunction

function! wildsearch#python_sort(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#pipeline#component#python_sort#make(l:args)
endfunction
