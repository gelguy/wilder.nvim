function! wilder#pipeline#component#python_search#make(opts) abort
  return {ctx, x -> {-> _wilder_python_search(a:opts, ctx, x)}}
endfunction
