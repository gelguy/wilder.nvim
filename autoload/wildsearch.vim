function! wildsearch#_sleep(t)
  return {ctx, x -> wildsearch#pipeline#null(_wildsearch_python_sleep(a:t, ctx, x))}
endfunction

function! wildsearch#branch(...)
  return wildsearch#pipeline#component#branch#make(a:000)
endfunction

function! wildsearch#check(...)
  return wildsearch#pipeline#component#check#make(a:000)
endfunction

function! wildsearch#check_empty()
  return {_, x -> empty(x) ? v:false : x}
endfunction

function! wildsearch#vim_substring()
  return {_, x -> x . '\k*'}
endfunction

function! wildsearch#vim_search(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#pipeline#component#vim_search#make(l:args)
endfunction

function! wildsearch#vim_sort()
  return {_, x -> sort(copy(x))}
endfunction

function! wildsearch#python_substring()
  return {_, x -> x . '\w*'}
endfunction

function! wildsearch#python_fuzzy_match(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#pipeline#component#python_fuzzy_match#make(l:args)
endfunction

function! wildsearch#python_fuzzy_delimiter(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#pipeline#component#python_fuzzy_delimiter#make(l:args)
endfunction

function! wildsearch#python_search(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#pipeline#component#python_search#make(l:args)
endfunction

function! wildsearch#python_uniq()
  return {ctx, x -> wildsearch#pipeline#null(_wildsearch_python_uniq(ctx, x))}
endfunction

function! wildsearch#python_sort()
  return wildsearch#pipeline#component#python_sort#make()
endfunction

function! wildsearch#python_fuzzy_sort()
  return wildsearch#pipeline#component#python_fuzzy_sort#make()
endfunction

function! wildsearch#history(...)
  if a:0 > 0
    return wildsearch#pipeline#component#history#make(a:1)
  else
    return wildsearch#pipeline#component#history#make()
  endif
endfunction

function! wildsearch#index(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#render#component#index#make(l:args)
endfunction

function! wildsearch#spinner(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#render#component#spinner#make(l:args)
endfunction

function! wildsearch#string(str, ...)
  let l:res = {
        \ 'f': a:str,
        \ }

  if a:0 > 0
    let l:res.hl = a:1
  endif

  return l:res
endfunction

function! wildsearch#separator(str, from_hl, to_hl)
  let l:from_bg = wildsearch#render#get_background_colors(a:from_hl)
  let l:to_bg = wildsearch#render#get_background_colors(a:to_hl)

  let l:colors = [[l:from_bg[0], l:to_bg[0]], [l:from_bg[1], l:to_bg[1]]]

  let l:hl_name = wildsearch#render#make_hl(l:colors)

  return {
        \ 'f': a:str,
        \ 'hl': l:hl_name,
        \ }
endfunction

function! wildsearch#previous_arrow(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#render#component#arrows#make_previous(l:args)
endfunction

function! wildsearch#next_arrow(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wildsearch#render#component#arrows#make_next(l:args)
endfunction
