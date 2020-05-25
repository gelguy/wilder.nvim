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
  call timer_start(0, {-> wilder#pipeline#resolve(a:ctx, a:x)})
endfunction

function! wilder#reject(ctx, x)
  call timer_start(0, {-> wilder#pipeline#reject(a:ctx, a:x)})
endfunction

" DEPRECATED: use wilder#resolve()
function! wilder#on_finish(ctx, x)
  return wilder#pipeline#resolve(a:ctx, a:x)
endfunction

" DEPRECATED: use wilder#reject()
function! wilder#on_error(ctx, x)
  return wilder#pipeline#reject(a:ctx, a:x)
endfunction

function! wilder#wait(f, ...)
  if !a:0
    return wilder#pipeline#wait(a:f)
  elseif a:0 == 1
    return wilder#pipeline#wait(a:f, a:1)
  else
    return wilder#pipeline#wait(a:f, a:1, a:2)
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

function! wilder#make_hl(name, args, ...) abort
  return wilder#render#make_hl(a:name, a:args, a:000)
endfunction

function! wilder#hl_with_attr(name, hl_group, ...) abort
  let l:attrs = {}
  for l:attr in a:000
    let l:attrs[l:attr] = v:true
  endfor
  return wilder#make_hl(a:name, a:hl_group, [{}, l:attrs, l:attrs])
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

function! wilder#query_common_subsequence_spans(...)
  let l:opts = get(a:, 1, {})
  let l:language = get(l:opts, 'language', 'vim')
  let l:case_sensitive = get(l:opts, 'case_sensitive', 0)

  if l:language ==# 'python'
    return {ctx, data, str -> has_key(data, 'query') ?
          \ wilder#python_common_subsequence_spans(
          \   str, data['query'], l:case_sensitive) : 0}
  endif

  return {ctx, data, str -> has_key(data, 'query') ?
        \ wilder#vim_common_subsequence_spans(
        \   str, data['query'], l:case_sensitive) : 0}
endfunction

function! wilder#vim_common_subsequence_spans(str, query, case_sensitive)
  let l:split_str = split(a:str, '\zs')
  let l:split_query = split(a:query, '\zs')

  let l:spans = []
  let l:span = [-1, -1]

  let l:byte_pos = 0
  let l:i = 0
  let l:j = 0
  while l:i < len(l:split_str) && l:j < len(l:split_query)
    if a:case_sensitive
      let l:match = l:split_str[l:i] ==# l:split_query[l:j]
    else
      let l:match = l:split_str[l:i] ==? l:split_query[l:j]
    endif

    if l:match
      let l:j += 1

      if l:span[0] == -1
        let l:span[0] = l:byte_pos
        let l:span[1] = strlen(l:split_str[l:i])
      else
        let l:span[1] += strlen(l:split_str[l:i])
      endif
    endif

    if !l:match && l:span[0] != -1
      call add(l:spans, l:span)
      let l:span = [-1, -1]
    endif

    let l:byte_pos += strlen(l:split_str[l:i])
    let l:i += 1
  endwhile

  if l:span[0] != -1
    call add(l:spans, l:span)
  endif

  return l:spans
endfunction

function! wilder#python_common_subsequence_spans(str, query, case_sensitive)
  return _wilder_python_common_subsequence_spans(a:str, a:query, a:case_sensitive)
endfunction

function! wilder#pcre2_capture_spans(...)
  let l:opts = get(a:, 1, {})
  let l:language = get(l:opts, 'language', 'python')

  if l:language ==# 'lua'
    return {ctx, data, str -> has_key(data, 'pcre2.pattern') ?
          \ wilder#lua_pcre2_capture_spans(data['pcre2.pattern'], str) : 0}
  endif

  let l:engine = get(l:opts, 'engine', 're')
  return {ctx, data, str -> has_key(data, 'pcre2.pattern') ?
        \ wilder#python_pcre2_capture_spans(data['pcre2.pattern'], str, l:engine) : 0}
endfunction

function! wilder#python_pcre2_capture_spans(pattern, str, ...)
  let l:engine = get(a:, 1, 're')
  return _wilder_python_pcre2_capture_spans(a:pattern, a:str, l:engine)
endfunction

function! wilder#lua_pcre2_capture_spans(pattern, str)
  let l:spans = luaeval(
        \ 'require("wilder").pcre2_capture_spans(_A[1], _A[2])',
        \ [a:pattern, a:str])

  " remove first element which is the matched string
  " convert from [{start+1}, {end+1}] to [{start}, {len}]
  return map(l:spans[1:], {i, s -> [s[0] - 1, s[1] - s[0] + 1]})
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

function! wilder#map(...) abort
  return wilder#pipeline#component#map#make(a:000)
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

function! wilder#result_output_escape(chars) abort
  return wilder#result({
        \'output': [{ctx, x -> escape(x, a:chars)}],
        \ })
endfunction

function! wilder#sequence(...) abort
  return wilder#pipeline#component#sequence#make(a:000)
endfunction

function! wilder#vim_substring() abort
  return {_, x -> x . (x[-1:] ==# '\' ? '\' : '') . '\k*'}
endfunction

function! wilder#vim_search(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#pipeline#component#vim_search#make(l:args)
endfunction

function! wilder#vim_sort() abort
  return {_, x -> sort(copy(x))}
endfunction

function! wilder#escape_python(str, ...) abort
  let l:escaped_chars = get(a:, 1, '^$*+?|(){}[]')

  let l:chars = split(a:str, '\zs')
  let l:res = ''

  let l:i = 0
  while l:i < len(l:chars)
    let l:char = l:chars[l:i]
    if l:char ==# '\'
      if l:i+1 < len(l:chars)
        let l:res .= '\' . l:chars[l:i+1]
        let l:i += 2
      else
        let l:res .= '\\'
        let l:i += 1
      endif
    elseif stridx(l:escaped_chars, l:char) != -1
      let l:res .= '\' . l:char
      let l:i += 1
    else
      let l:res .= l:char
      let l:i += 1
    endif
  endwhile

  return l:res
endfunction

function! wilder#python_substring() abort
  return {_, x -> '(' . wilder#escape_python(x) . ')\w*'}
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

function! wilder#python_sort_difflib(ctx, xs, query) abort
  return {ctx -> _wilder_python_sort_difflib(ctx, a:xs, a:query)}
endfunction

function! wilder#python_sort_fuzzywuzzy(ctx, xs, query) abort
  return {ctx -> _wilder_python_sort_fuzzywuzzy(ctx, a:xs, a:query)}
endfunction

" DEPRECATED: use wilder#python_sort_fuzzywuzzy()
function! wilder#python_fuzzywuzzy(ctx, xs, query) abort
  return wilder#python_sort_fuzzywuzzy(a:ctx, a:xs, a:query)
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

  if !get(l:opts, 'skip_check', 0)
    let l:pipeline = [
          \ wilder#check({_, x -> !empty(x)}),
          \ wilder#check({-> getcmdtype() ==# '/' || getcmdtype() ==# '?'}),
          \ ]
  else
    let l:pipeline = []
  endif

  let l:search_pipeline = get(l:opts, 'pipeline', [
        \ wilder#vim_substring(),
        \ wilder#vim_search(),
        \ wilder#result_output_escape('^$*~[]/\'),
        \ ])

  let l:pipeline += [
        \ wilder#map(
        \   l:search_pipeline,
        \   [{ctx, x -> x}]
        \ ),
        \ {ctx, xs -> wilder#result({
        \   'data': {'query': xs[1]},
        \ })(ctx, xs[0])}
        \ ]

  return l:pipeline
endfunction

function! wilder#vim_search_pipeline(...) abort
  return wilder#search_pipeline(get(a:, 1, {}))
endfunction

function! s:extract_keys(obj, ...)
  let l:res = {}

  for l:key in a:000
    if has_key(a:obj, l:key)
      let l:res[l:key] = a:obj[l:key]
    endif
  endfor

  return l:res
endfunction

function! wilder#python_search_pipeline(...) abort
  let l:opts = get(a:, 1, {})

  let l:pipeline = []

  let l:Regex = get(l:opts, 'regex', 'substring')
  if type(l:Regex) is v:t_func
    call add(l:pipeline, l:Regex)
  elseif l:Regex ==# 'fuzzy'
    call add(l:pipeline, wilder#python_fuzzy_match())
  elseif l:Regex ==# 'fuzzy_delimiter'
    call add(l:pipeline, wilder#python_fuzzy_delimiter())
  else
    call add(l:pipeline, wilder#python_substring())
  endif

  let l:subpipeline = []

  call add(l:subpipeline, wilder#python_search(
        \ s:extract_keys(l:opts, 'max_candidates', 'engine')))

  let l:Sort = get(l:opts, 'sort', 0)
  if l:Sort isnot 0
    if l:Sort is 'python_sort_fuzzywuzzy'
      let l:Sort = function('wilder#python_sort_fuzzywuzzy')
    elseif l:Sort is 'python_sort_difflib'
      let l:Sort = function('wilder#python_sort_difflib')
    endif

    call add(l:subpipeline, {ctx, xs -> l:Sort(ctx, xs, ctx.input)})
  endif

  call add(l:subpipeline, wilder#result_output_escape('^$*~[]/\'))

  call add(l:pipeline, wilder#map(
        \ l:subpipeline,
        \ [{ctx, x -> x}]
        \ ))

  call add(l:pipeline, {ctx, xs -> wilder#result({
        \ 'data': {'pcre2.pattern': xs[1]},
        \ })(ctx, xs[0])})

  return wilder#search_pipeline({
        \ 'pipeline': l:pipeline,
        \ 'skip_check': get(l:opts, 'skip_check', 0),
        \ })
endfunction

function! wilder#cmdline_pipeline(...) abort
  return wilder#cmdline#pipeline(get(a:, 1, {}))
endfunction

function! wilder#substitute_pipeline(...) abort
  return wilder#cmdline#substitute_pipeline(get(a:, 1, {}))
endfunction

function! wilder#fuzzy_filter() abort
  return wilder#cmdline#fuzzy_filter()
endfunction

function! wilder#python_fuzzy_filter(...) abort
  if a:0
    return wilder#cmdline#python_fuzzy_filter(a:1)
  else
    return wilder#cmdline#python_fuzzy_filter()
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
  return wilder#render#renderer#statusline#make(l:args)
endfunction

function! wilder#float_renderer(...)
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#render#renderer#float#make(l:args)
endfunction
