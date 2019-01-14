function! wilder#in_context()
  return wilder#main#in_context()
endfunction

function! wilder#enable_cmdline_enter()
  return wilder#main#enable_cmdline_enter()
endfunction

function! wilder#next()
  return wilder#main#next()
endfunction

function! wilder#previous()
  return wilder#main#previous()
endfunction

function! wilder#can_reject_completion()
  return wilder#main#can_reject_completion()
endfunction

function! wilder#reject_completion()
  return wilder#main#reject_completion()
endfunction

function! wilder#can_accept_completion()
  return wilder#main#can_accept_completion()
endfunction

function! wilder#accept_completion()
  return wilder#main#accept_completion()
endfunction

function! wilder#start_from_normal_mode()
  return wilder#main#start_from_normal_mode()
endfunction

function! wilder#toggle()
  return wilder#main#toggle()
endfunction

function! wilder#set_option(x, ...) abort
  if len(a:000) == 0
    call wilder#options#set(a:x)
  else
    call wilder#options#set(a:x, a:1)
  endif
endfunction

function! wilder#_sleep(t) abort
  " lambda functions do not have func-abort
  " so it is possible for timer_start to throw an error
  " followed by on_finish being called
  return {ctx, x -> {-> timer_start(a:t, {-> wilder#pipeline#on_finish(ctx, x)})}}
endfunction

function! wilder#branch(...) abort
  return wilder#pipeline#component#branch#make(a:000)
endfunction

function! wilder#check(...) abort
  return wilder#pipeline#component#check#make(a:000)
endfunction

function! wilder#result(...) abort
  if a:0 == 0
    return wilder#pipeline#component#result#make()
  else
    return wilder#pipeline#component#result#make(a:1)
  endif
endfunction

function! wilder#result_escape(chars) abort
  return wilder#result({
        \'output': {ctx, x, prev -> escape(prev(ctx, x), a:chars)},
        \ })
endfunction

function! wilder#vim_substring() abort
  return {_, x -> x . '\k*'}
endfunction

function! wilder#vim_search(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#pipeline#component#vim_search#make(l:args)
endfunction

function! wilder#vim_sort() abort
  return {_, x -> sort(copy(x))}
endfunction

function! wilder#vim_uniq() abort
  return wilder#pipeline#component#vim_uniq#make()
endfunction

function! wilder#python_substring() abort
  return {_, x -> x . '\w*'}
endfunction

function! wilder#python_fuzzy_match(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#pipeline#component#python_fuzzy_match#make(l:args)
endfunction

function! wilder#python_fuzzy_delimiter(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#pipeline#component#python_fuzzy_delimiter#make(l:args)
endfunction

function! wilder#python_search(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#pipeline#component#python_search#make(l:args)
endfunction

function! wilder#python_uniq() abort
  return {ctx, x -> wilder#pipeline#null(_wild_python_uniq(ctx, x))}
endfunction

function! wilder#python_sort() abort
  return wilder#pipeline#component#python_sort#make()
endfunction

function! wilder#_python_sleep(t) abort
  return {ctx, x -> {-> _wilder_python_sleep(a:t, ctx, x)}}
endfunction

function! wilder#history(...) abort
  if a:0 == 0
    return wilder#pipeline#component#history#make()
  elseif a:0 == 1
    return wilder#pipeline#component#history#make(a:1)
  else
    return wilder#pipeline#component#history#make(a:1, a:2)
  endif
endfunction

function! wilder#search_pipeline(...) abort
  let l:opts = a:0 > 0 ? a:1 : {}

  let l:result = [
        \ wilder#check({_, x -> !empty(x)}),
        \ wilder#check({-> getcmdtype() ==# '/' || getcmdtype() ==# '?'}),
        \ ]

  let l:result += get(l:opts, 'pipeline', [
        \ wilder#vim_substring(),
        \ wilder#vim_search(),
        \ wilder#result_escape('^$,*~[]/\'),
        \ ])

  return l:result
endfunction

function! wilder#vim_search_pipeline() abort
  return wilder#search_pipeline()
endfunction

function! wilder#python_search_pipeline() abort
  return wilder#search_pipeline({
        \ 'pipeline': [
        \   wilder#python_substring(),
        \   wilder#python_search(),
        \   wilder#result_escape('^$,*~[]/\'),
        \ ],
        \ })
endfunction

function! wilder#cmdline_pipeline(...) abort
  let l:opts = a:0 > 0 ? a:1 : {}

  return wilder#cmdline#pipeline(l:opts)
endfunction

function! wilder#substitute_pipeline(...) abort
  let l:opts = a:0 > 0 ? a:1 : {}

  return wilder#cmdline#substitute_pipeline(l:opts)
endfunction

function! wilder#index(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#render#component#index#make(l:args)
endfunction

function! wilder#string(str, ...) abort
  let l:res = {
        \ 'stl': a:str,
        \ }

  if a:0 > 0
    let l:res.hl = a:1
  endif

  return l:res
endfunction

function! wilder#previous_arrow(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#render#component#arrows#make_previous(l:args)
endfunction

function! wilder#next_arrow(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#render#component#arrows#make_next(l:args)
endfunction

function! wilder#separator(str, from, to, ...) abort
  if a:0 > 0
    return wilder#render#component#separator#make(a:str, a:from, a:to, a:1)
  else
    return wilder#render#component#separator#make(a:str, a:from, a:to)
  endif
endfunction

function! wilder#spinner(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#render#component#spinner#make(l:args)
endfunction

function! wilder#condition(predicate, if_true, ...) abort
  let l:if_false = a:0 > 0 ? a:1 : []
  return wilder#render#component#condition#make(a:predicate, a:if_true, l:if_false)
endfunction

function! wilder#make_hl(name, args) abort
  return wilder#render#make_hl(a:name, a:args)
endfunction
