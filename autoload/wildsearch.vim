function! wildsearch#_sleep(t) abort
  return {ctx, x -> wildsearch#pipeline#null(_wildsearch_python_sleep(a:t, ctx, x))}
endfunction

function! wildsearch#branch(...) abort
  return wildsearch#pipeline#component#branch#make(a:000)
endfunction

function! wildsearch#map(...) abort
  return wildsearch#pipeline#component#map#make(a:000)
endfunction

function! wildsearch#check(...) abort
  return wildsearch#pipeline#component#check#make(a:000)
endfunction

function! wildsearch#vim_substring() abort
  return {_, x -> x . '\k*'}
endfunction

function! wildsearch#vim_search(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#pipeline#component#vim_search#make(l:args)
endfunction

function! wildsearch#vim_sort() abort
  return {_, x -> sort(copy(x))}
endfunction

function! wildsearch#vim_uniq() abort
  return wildsearch#pipeline#component#vim_uniq#make()
endfunction

function! wildsearch#python_substring() abort
  return {_, x -> x . '\w*'}
endfunction

function! wildsearch#python_fuzzy_match(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#pipeline#component#python_fuzzy_match#make(l:args)
endfunction

function! wildsearch#python_fuzzy_delimiter(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#pipeline#component#python_fuzzy_delimiter#make(l:args)
endfunction

function! wildsearch#python_search(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#pipeline#component#python_search#make(l:args)
endfunction

function! wildsearch#python_uniq() abort
  return {ctx, x -> wildsearch#pipeline#null(_wildsearch_python_uniq(ctx, x))}
endfunction

function! wildsearch#python_sort() abort
  return wildsearch#pipeline#component#python_sort#make()
endfunction

function! wildsearch#history(...) abort
  if a:0 == 0
    return wildsearch#pipeline#component#history#make()
  elseif a:0 == 1
    return wildsearch#pipeline#component#history#make(a:1)
  else
    return wildsearch#pipeline#component#history#make(a:1, a:2)
  endif
endfunction

function! wildsearch#index(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#render#component#index#make(l:args)
endfunction

function! wildsearch#string(str, ...) abort
  let l:res = {
        \ 'stl': a:str,
        \ }

  if a:0 > 0
    let l:res.hl = a:1
  endif

  return l:res
endfunction

function! wildsearch#previous_arrow(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#render#component#arrows#make_previous(l:args)
endfunction

function! wildsearch#next_arrow(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#render#component#arrows#make_next(l:args)
endfunction

function! wildsearch#separator(str, from, to, ...) abort
  if a:0 > 0
    return wildsearch#render#component#separator#make(a:str, a:from, a:to, a:1)
  else
    return wildsearch#render#component#separator#make(a:str, a:from, a:to)
  endif
endfunction

function! wildsearch#spinner(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#render#component#spinner#make(l:args)
endfunction

function! wildsearch#condition(predicate, if_true, ...) abort
  let l:if_false = a:0 > 0 ? a:1 : []
  return wildsearch#render#component#condition#make(a:predicate, a:if_true, l:if_false)
endfunction

function! wildsearch#vim_search_pipeline(...)
  let l:opts = a:0 > 0 ? a:1 : {}

  return [
        \ wildsearch#check({_, x -> !empty(x)}),
        \ wildsearch#check({-> getcmdtype() ==# '/' || getcmdtype() ==# '?'}),
        \ wildsearch#vim_substring(),
        \ wildsearch#vim_search(l:opts),
        \ {_, xs -> map(copy(xs), {i, x -> {'result': x, 'draw': escape(x, '^$.*~[]\')}})},
        \ ]
endfunction

function! wildsearch#python_search_pipeline(...)
  let l:opts = a:0 > 0 ? a:1 : {}

  return [
        \ wildsearch#check({_, x -> !empty(x)}),
        \ wildsearch#check({-> getcmdtype() ==# '/' || getcmdtype() ==# '?'}),
        \ wildsearch#python_substring(),
        \ wildsearch#python_search(l:opts),
        \ {_, xs -> map(copy(xs), {i, x -> {'result': x, 'draw': escape(x, '^$.*~[]\')}})},
        \ ]
endfunction

function! wildsearch#getcompletion_pipeline(...) abort
  let l:opts = a:0 > 0 ? a:1 : {}

  return wildsearch#getcompletion#pipeline(l:opts)
endfunction
