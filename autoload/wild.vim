function! wild#_sleep(t) abort
  return {ctx, x -> wild#pipeline#null(_wild_python_sleep(a:t, ctx, x))}
endfunction

function! wild#branch(...) abort
  return wild#pipeline#component#branch#make(a:000)
endfunction

function! wild#map(...) abort
  return wild#pipeline#component#map#make(a:000)
endfunction

function! wild#check(...) abort
  return wild#pipeline#component#check#make(a:000)
endfunction

function! wild#vim_substring() abort
  return {_, x -> x . '\k*'}
endfunction

function! wild#vim_search(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wild#pipeline#component#vim_search#make(l:args)
endfunction

function! wild#vim_sort() abort
  return {_, x -> sort(copy(x))}
endfunction

function! wild#vim_uniq() abort
  return wild#pipeline#component#vim_uniq#make()
endfunction

function! wild#python_substring() abort
  return {_, x -> x . '\w*'}
endfunction

function! wild#python_fuzzy_match(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wild#pipeline#component#python_fuzzy_match#make(l:args)
endfunction

function! wild#python_fuzzy_delimiter(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wild#pipeline#component#python_fuzzy_delimiter#make(l:args)
endfunction

function! wild#python_search(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wild#pipeline#component#python_search#make(l:args)
endfunction

function! wild#python_uniq() abort
  return {ctx, x -> wild#pipeline#null(_wild_python_uniq(ctx, x))}
endfunction

function! wild#python_sort() abort
  return wild#pipeline#component#python_sort#make()
endfunction

function! wild#history(...) abort
  if a:0 == 0
    return wild#pipeline#component#history#make()
  elseif a:0 == 1
    return wild#pipeline#component#history#make(a:1)
  else
    return wild#pipeline#component#history#make(a:1, a:2)
  endif
endfunction

function! wild#index(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wild#render#component#index#make(l:args)
endfunction

function! wild#string(str, ...) abort
  let l:res = {
        \ 'stl': a:str,
        \ }

  if a:0 > 0
    let l:res.hl = a:1
  endif

  return l:res
endfunction

function! wild#previous_arrow(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wild#render#component#arrows#make_previous(l:args)
endfunction

function! wild#next_arrow(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wild#render#component#arrows#make_next(l:args)
endfunction

function! wild#separator(str, from, to, ...) abort
  if a:0 > 0
    return wild#render#component#separator#make(a:str, a:from, a:to, a:1)
  else
    return wild#render#component#separator#make(a:str, a:from, a:to)
  endif
endfunction

function! wild#spinner(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wild#render#component#spinner#make(l:args)
endfunction

function! wild#condition(predicate, if_true, ...) abort
  let l:if_false = a:0 > 0 ? a:1 : []
  return wild#render#component#condition#make(a:predicate, a:if_true, l:if_false)
endfunction

function! wild#search_pipeline(...)
  let l:opts = a:0 > 0 ? a:1 : {}

  let l:result = [
        \ wild#check({_, x -> !empty(x)}),
        \ wild#check({-> getcmdtype() ==# '/' || getcmdtype() ==# '?'}),
        \ ]

  let l:result += get(l:opts, 'pipeline', [
        \ wild#vim_substring(),
        \ wild#vim_search(),
        \ ])

  let l:result += [
        \ {_, xs -> map(copy(xs), {i, x -> {'result': x, 'draw': escape(x, '^$.*~[]\')}})},
        \ ]

  return l:result
endfunction

function! wild#vim_search_pipeline()
  return wild#search_pipeline()
endfunction

function! wild#python_search_pipeline()
  return wild#search_pipeline({
        \ 'pipeline': [
        \   wild#python_substring(),
        \   wild#python_search(),
        \ ],
        \ })
endfunction

function! wild#cmdline_pipeline(...) abort
  let l:opts = a:0 > 0 ? a:1 : {}

  return wild#cmdline#pipeline(l:opts)
endfunction

function! wild#substitute_pipeline(...) abort
  let l:opts = a:0 > 0 ? a:1 : {}

  return wild#cmdline#substitute_pipeline(l:opts)
endfunction
