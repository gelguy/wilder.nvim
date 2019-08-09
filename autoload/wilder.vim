function! wilder#in_context()
  return wilder#main#in_context()
endfunction

function! wilder#enable_cmdline_enter()
  return wilder#main#enable_cmdline_enter()
endfunction

function! wilder#enable()
  return wilder#main#enable()
endfunction

function! wilder#disable()
  return wilder#main#disable()
endfunction

function! wilder#toggle()
  return wilder#main#toggle()
endfunction

function! wilder#set_option(x, ...) abort
  if !a:0
    call wilder#options#set(a:x)
  else
    call wilder#options#set(a:x, a:1)
  endif
endfunction

function! wilder#next()
  return wilder#main#next()
endfunction

function! wilder#previous()
  return wilder#main#previous()
endfunction

function! wilder#resolve(ctx, x)
  return wilder#pipeline#resolve(a:ctx, a:x)
endfunction

function! wilder#reject(ctx, x)
  return wilder#pipeline#reject(a:ctx, a:x)
endfunction

" DEPRECATED: use wilder#resolve()
function! wilder#on_finish(ctx, x)
  return wilder#pipeline#resolve(a:ctx, a:x)
endfunction

" DEPRECATED: use wilder#reject()
function! wilder#on_error(ctx, x)
  return wilder#pipeline#reject(a:ctx, a:x)
endfunction

function! wilder#wait(f, on_finish, ...)
  if !a:0
    return wilder#pipeline#wait(a:f, a:on_finish)
  else
    return wilder#pipeline#wait(a:f, a:on_finish, a:1)
  endif
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

function! wilder#make_hl(name, args) abort
  return wilder#render#make_hl(a:name, a:args)
endfunction

function! wilder#flatten(xss) abort
  if empty(a:xss)
    return []
  endif

  let l:result = a:xss[0]

  for l:xs in a:xss[1 :]
    let l:result += l:xs
  endfor

  return l:result
endfunction

function! wilder#uniq(xs, ...) abort
  let l:seen = {}
  let l:res = []

  for l:element in a:xs
    let l:key = a:0 ? a:1(l:element) : l:element

    if !has_key(l:seen, l:key)
      let l:seen[l:key] = 1
      call add(l:res, l:key)
    endif
  endfor

  return l:res
endfunction

" pipeline components

function! wilder#_sleep(t) abort
  " lambda functions do not have func-abort
  " so it is possible for timer_start to throw an error
  " followed by resolve being called
  return {_, x -> {ctx -> timer_start(a:t, {-> wilder#resolve(ctx, x)})}}
endfunction

function! wilder#branch(...) abort
  return wilder#pipeline#component#branch#make(a:000)
endfunction

function! wilder#check(...) abort
  return wilder#pipeline#component#check#make(a:000)
endfunction

function! wilder#result(...) abort
  if !a:0
    return wilder#pipeline#component#result#make()
  else
    return wilder#pipeline#component#result#make(a:1)
  endif
endfunction

function! wilder#result_fmap(f) abort
  return wilder#pipeline#component#result_fmap#make(a:f)
endfunction

function! wilder#result_output_escape(chars) abort
  return wilder#result({
        \'output': [{ctx, x -> escape(x, a:chars)}],
        \ })
endfunction

function! wilder#sequence(...) abort
  return wilder#pipeline#component#sequence#make(a:000)
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
  let l:opts = a:0 > 0 ? a:1 : {}
  return {_, x -> {ctx -> _wilder_python_search(ctx, l:opts, x)}}
endfunction

function! wilder#python_uniq() abort
  return {_, x -> {ctx -> _wilder_python_uniq(ctx, x)}}
endfunction

function! wilder#python_sort() abort
  return {_, x -> {ctx -> _wilder_python_sort(ctx, x)}}
endfunction

function! wilder#_python_sleep(t) abort
  return {_, x -> {ctx -> _wilder_python_sleep(ctx, a:t, x)}}
endfunction

function! wilder#python_fuzzywuzzy(ctx, xs, query) abort
  return {ctx -> _wilder_python_fuzzywuzzy(ctx, a:xs, a:query)}
endfunction

function! wilder#history(...) abort
  if !a:0
    return wilder#pipeline#component#history#make()
  elseif a:0 == 1
    return wilder#pipeline#component#history#make(a:1)
  else
    return wilder#pipeline#component#history#make(a:1, a:2)
  endif
endfunction

" pipelines

function! wilder#search_pipeline(...) abort
  let l:opts = a:0 > 0 ? a:1 : {}

  let l:result = [
        \ wilder#check({_, x -> !empty(x)}),
        \ wilder#check({-> getcmdtype() ==# '/' || getcmdtype() ==# '?'}),
        \ ]

  let l:result += get(l:opts, 'pipeline', [
        \ wilder#vim_substring(),
        \ wilder#vim_search(),
        \ wilder#result_output_escape('^$,*~[]/\'),
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
        \   wilder#result_output_escape('^$,*~[]/\'),
        \ ],
        \ })
endfunction

function! wilder#cmdline_pipeline(...) abort
  return wilder#cmdline#pipeline(get(a:, 1, {}))
endfunction

function! wilder#substitute_pipeline(...) abort
  let l:opts = a:0 > 0 ? a:1 : {}

  return wilder#cmdline#substitute_pipeline(l:opts)
endfunction

function! wilder#fuzzy_filter() abort
  return wilder#cmdline#fuzzy_filter()
endfunction

function! wilder#python_fuzzy_filter(...) abort
  if a:0
    return wilder#cmdline#python_fuzzy_filter(a:1)
  else
    return wilder#cmdline#fuzzy_filter()
  endif
endfunction

" render components

function! wilder#index(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#render#component#index#make(l:args)
endfunction

function! wilder#string(str, ...) abort
  return {'value': a:str, 'hl': get(a:000, 0, '')}
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
  if a:0
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

" renderers

function! wilder#statusline_renderer(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#render#statusline#renderer(l:args)
endfunction

function! wilder#float_renderer(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#render#float#renderer(l:args)
endfunction
