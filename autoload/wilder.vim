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
  return call('wilder#resolve', [a:ctx, a:x])
endfunction

" DEPRECATED: use wilder#reject()
function! wilder#on_error(ctx, x)
  return call('wilder#reject', [a:ctx, a:x])
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

function! wilder#query_highlighter(...)
  let l:opts = get(a:, 1, {})
  return wilder#highlighter#query_highlighter(l:opts)
endfunction

" DEPRECATED: use wilder#query_highlighter()
function! wilder#query_common_subsequence_spans(...)
  return call('wilder#query_highlighter', a:000)
endfunction

function! wilder#pcre2_highlighter(...)
  let l:opts = get(a:, 1, {})
  return wilder#highlighter#pcre2_highlighter(l:opts)
endfunction

" DEPRECATED: use wilder#pcre2_highlighter()
function! wilder#pcre2_capture_spans(...)
  return call('wilder#pcre2_highlighter', a:000)
endfunction

function! wilder#cpsm_highlighter(...)
  let l:opts = get(a:, 1, {})
  return wilder#highlighter#cpsm_highlighter(l:opts)
endfunction

" pipes

function! wilder#_sleep(t) abort
  " lambda functions do not have func-abort
  " so it is possible for timer_start to throw an error
  " followed by resolve being called
  return {_, x -> {ctx -> timer_start(a:t, {-> wilder#resolve(ctx, x)})}}
endfunction

function! wilder#branch(...) abort
  return wilder#pipe#branch#make(a:000)
endfunction

function! wilder#map(...) abort
  return wilder#pipe#map#make(a:000)
endfunction

function! wilder#subpipeline(f) abort
  return wilder#pipe#subpipeline#make(a:f)
endfunction

function! wilder#check(...) abort
  return wilder#pipe#check#make(a:000)
endfunction

function! wilder#debounce(t) abort
  return wilder#pipe#debounce#make(a:t)
endfunction

function! wilder#result(...) abort
  if !a:0
    return wilder#pipe#result#make()
  else
    return wilder#pipe#result#make(a:1)
  endif
endfunction

function! wilder#result_output_escape(chars) abort
  return wilder#result({
        \'output': [{ctx, x -> escape(x, a:chars)}],
        \ })
endfunction

function! wilder#sequence(...) abort
  return wilder#pipe#sequence#make(a:000)
endfunction

function! wilder#vim_substring() abort
  return {_, x -> x . (x[-1:] ==# '\' ? '\' : '') . '\k*'}
endfunction

function! wilder#vim_search(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#pipe#vim_search#make(l:args)
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
  return wilder#pipe#python_fuzzy_match#make(l:args)
endfunction

function! wilder#python_fuzzy_delimiter(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#pipe#python_fuzzy_delimiter#make(l:args)
endfunction

function! wilder#python_search(...) abort
  let l:opts = a:0 > 0 ? a:1 : {}
  return {_, x -> {ctx -> _wilder_python_search(ctx, l:opts, x)}}
endfunction

function! wilder#python_uniq() abort
  return {_, x -> {ctx -> _wilder_python_uniq(ctx, x)}}
endfunction

function! wilder#_python_sleep(t) abort
  return {_, x -> {ctx -> _wilder_python_sleep(ctx, a:t, x)}}
endfunction

function! wilder#history(...) abort
  if !a:0
    return wilder#pipe#history#make()
  elseif a:0 == 1
    return wilder#pipe#history#make(a:1)
  else
    return wilder#pipe#history#make(a:1, a:2)
  endif
endfunction

function! wilder#python_sort() abort
  return {_, x -> {ctx -> _wilder_python_sort(ctx, x)}}
endfunction

" sorters

function! wilder#python_sorter_difflib(...) abort
  let l:opts = {
        \ 'quick': get(a:, 1, 1),
        \ 'case_sensitive': get(a:, 2, 1),
        \ }
  return {ctx, xs, query -> wilder#python_sort_difflib(ctx, l:opts, xs, query)}
endfunction

function! wilder#python_sort_difflib(ctx, opts, xs, query) abort
  return {ctx -> _wilder_python_sort_difflib(ctx, a:opts, a:xs, a:query)}
endfunction

function! wilder#python_sorter_fuzzywuzzy(...) abort
  let l:opts = {
        \ 'partial': get(a:, 1, 1),
        \ }
  return {ctx, xs, query -> wilder#python_sort_fuzzywuzzy(ctx, l:opts, xs, query)}
endfunction

" DEPRECATED: use wilder#python_sort_fuzzywuzzy()
function! wilder#python_fuzzywuzzy(ctx, xs, query) abort
  return call('wilder#python_sort_fuzzywuzzy', [a:ctx, {}, a:xs, a:query])
endfunction

function! wilder#python_sort_fuzzywuzzy(ctx, opts, xs, query) abort
  return {ctx -> _wilder_python_sort_fuzzywuzzy(ctx, a:opts, a:xs, a:query)}
endfunction

" filters

" DEPRECATED: use wilder#filter_fuzzy()
function! wilder#fuzzy_filter() abort
  return call('wilder#filter_fuzzy', [])
endfunction

function! wilder#filter_fuzzy() abort
  return {ctx, xs, q -> wilder#filt_fuzzy(ctx, {}, xs, q)}
endfunction

function! wilder#filt_fuzzy(ctx, opts, candidates, query) abort
  return wilder#cmdline#filter_fuzzy(a:ctx, a:candidates, a:query)
endfunction

" DEPRECATED: use wilder#python_filter_fuzzy()
function! wilder#python_fuzzy_filter(...) abort
  return call('wilder#python_filter_fuzzy', a:000)
endfunction

function! wilder#python_filter_fuzzy(...) abort
  let l:opts = {
        \ 'engine': get(a:, 1, 're'),
        \ }
  return {ctx, xs, q -> wilder#python_filt_fuzzy(ctx, l:opts, xs, q)}
endfunction

function! wilder#python_filt_fuzzy(ctx, opts, candidates, query) abort
  return wilder#cmdline#python_filter_fuzzy(a:ctx, a:opts, a:candidates, a:query)
endfunction

function! wilder#python_filter_fruzzy(...) abort
  let l:opts = {
        \ 'limit': get(a:, 1, 1000),
        \ 'fruzzy_path': get(a:, 2, wilder#fruzzy_path()),
        \ }
  return {ctx, xs, q -> wilder#python_filt_fruzzy(ctx, l:opts, xs, q)}
endfunction

function! wilder#python_filt_fruzzy(ctx, opts, candidates, query) abort
  return wilder#cmdline#python_filter_fruzzy(a:ctx, a:opts, a:candidates, a:query)
endfunction

function! wilder#python_filter_cpsm(...) abort
  let l:opts = {
        \ 'cpsm_path': get(a:, 1, wilder#cpsm_path()),
        \ }
  return {ctx, xs, q -> wilder#python_filt_cpsm(ctx, l:opts, xs, q)}
endfunction

function! wilder#python_filt_cpsm(ctx, opts, candidates, query) abort
  return wilder#cmdline#python_filter_cpsm(a:ctx, a:opts, a:candidates, a:query)
endfunction

" pipelines

function! wilder#search_pipeline(...) abort
  let l:opts = get(a:, 1, {})

  return has('nvim') ?
        \ wilder#python_search_pipeline(l:opts) :
        \ wilder#vim_search_pipeline(l:opts)
endfunction

function! s:search_pipeline(...) abort
  let l:opts = a:0 > 0 ? a:1 : {}

  let l:pipeline = []
  if !get(l:opts, 'skip_cmdtype_check', 0)
    call add(l:pipeline,
          \ wilder#check({-> getcmdtype() ==# '/' || getcmdtype() ==# '?'}))
  endif

  if get(l:opts, 'debounce', 0) > 0
    call add(l:pipeline, wilder#debounce(l:opts['debounce']))
  endif

  let l:search_pipeline = get(l:opts, 'pipeline', [
        \ wilder#vim_substring(),
        \ wilder#vim_search(),
        \ wilder#result_output_escape('^$*~[]/\'),
        \ ])

  call add(l:pipeline,
        \ wilder#subpipeline({ctx, x -> l:search_pipeline + [
        \   wilder#result({'data': {'query': x}}),
        \ ]}))

  return l:pipeline
endfunction

function! wilder#vim_search_pipeline(...) abort
  return s:search_pipeline(get(a:, 1, {}))
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

  let l:Sorter = get(l:opts, 'sorter', get(l:opts, 'sort', 0))
  if l:Sorter isnot 0
    if l:Sorter is 'python_sort_fuzzywuzzy'
      let l:Sorter = wilder#python_sorter_fuzzywuzzy()
    elseif l:Sorter is 'python_sort_difflib'
      let l:Sorter = wilder#python_sorter_difflib()
    endif

    call add(l:subpipeline, {ctx, xs -> l:Sorter(ctx, xs, ctx.input)})
  endif

  call add(l:subpipeline, wilder#result_output_escape('^$*~[]/\'))

  call add(l:pipeline, wilder#subpipeline({ctx, x -> l:subpipeline + [
        \ wilder#result({'data': {'pcre2.pattern': x}}),
        \ ]}))

  return s:search_pipeline({
        \ 'debounce': get(l:opts, 'debounce', 0),
        \ 'pipeline': l:pipeline,
        \ 'skip_cmdtype_check': get(l:opts, 'skip_cmdtype_check', 0),
        \ })
endfunction

function! wilder#cmdline_pipeline(...) abort
  return wilder#cmdline#pipeline(get(a:, 1, {}))
endfunction

function! wilder#substitute_pipeline(...) abort
  return wilder#cmdline#substitute_pipeline(get(a:, 1, {}))
endfunction

function! wilder#python_file_finder_pipeline(...) abort
  return wilder#cmdline#python_file_finder_pipeline(get(a:, 1, {}))
endfunction

" renderer items

" DEPRECATED: use wilder#wildmenu_index()
function! wilder#index(...) abort
  return call('wilder#wildmenu_index', a:000)
endfunction

function! wilder#wildmenu_index(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#renderer#wildmenu_item#index#make(l:args)
endfunction

" DEPRECATED: use wilder#wildmenu_string()
function! wilder#string(str, ...) abort
  return call('wilder#wildmenu_string', [str] + a:000)
endfunction

function! wilder#wildmenu_string(str, ...) abort
  return {'value': a:str, 'hl': get(a:000, 0, '')}
endfunction

" DEPRECATED: use wilder#wildmenu_previous_arrow()
function! wilder#previous_arrow(...) abort
  return call('wilder#wildmenu_previous_arrow', a:000)
endfunction

function! wilder#wildmenu_previous_arrow(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#renderer#wildmenu_item#arrows#make_previous(l:args)
endfunction

" DEPRECATED: use wilder#wildmenu_next_arrow()
function! wilder#next_arrow(...) abort
  return call('wilder#wildmenu_next_arrow', a:000)
endfunction

function! wilder#wildmenu_next_arrow(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#renderer#wildmenu_item#arrows#make_next(l:args)
endfunction

" DEPRECATED: use wilder#wildmenu_powerline_separator()
function! wilder#separator(str, from, to, ...) abort
  return call('wilder#wildmenu_powerline_separator', [a:str, a:from, a:to] + a:000)
endfunction

" DEPRECATED: use wilder#wildmenu_powerline_separator()
function! wilder#powerline_separator(str, from, to, ...) abort
  return call('wilder#wildmenu_powerline_separator', [a:str, a:from, a:to] + a:000)
endfunction

function! wilder#wildmenu_powerline_separator(str, from, to, ...) abort
  if a:0
    return wilder#renderer#wildmenu_item#separator#make(a:str, a:from, a:to, a:1)
  else
    return wilder#renderer#wildmenu_item#separator#make(a:str, a:from, a:to)
  endif
endfunction

" DEPRECATED: use wilder#wildmenu_spinner()
function! wilder#spinner(...) abort
  return call('wilder#wildmenu_spinner', a:000)
endfunction

function! wilder#wildmenu_spinner(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#renderer#wildmenu_item#spinner#make(l:args)
endfunction

" DEPRECATED: use wilder#wildmenu_condition()
function! wilder#condition(predicate, if_true, ...) abort
  return call('wilder#wildmenu_condition', [a:predicate, a:if_true] + a:000)
endfunction

function! wilder#wildmenu_condition(predicate, if_true, ...) abort
  let l:if_false = a:0 > 0 ? a:1 : []
  return wilder#renderer#wildmenu_item#condition#make(a:predicate, a:if_true, l:if_false)
endfunction

function! wilder#popupmenu_scrollbar(...) abort
  let l:args = get(a:, 1, {})
  return wilder#renderer#popupmenu_column#scrollbar#make(l:args)
endfunction

function! wilder#popupmenu_spinner(...) abort
  let l:args = get(a:, 1, {})
  return wilder#renderer#popupmenu_column#spinner#make(l:args)
endfunction

" renderers

function! wilder#renderer_mux(args)
  return wilder#renderer#mux#make(a:args)
endfunction

" DEPRECATED: use wilder#wildmenu_renderer()
function! wilder#statusline_renderer(...)
  let l:args = a:0 > 0 ? a:1 : {}
  call extend(l:args, {'mode': 'statusline'})
  return wilder#wildmenu_renderer(l:args)
endfunction

" DEPRECATED: use wilder#wildmenu_renderer()
function! wilder#float_renderer(...)
  let l:args = a:0 > 0 ? a:1 : {}
  call extend(l:args, {'mode': 'float'})
  return wilder#wildmenu_renderer(l:args)
endfunction

function! wilder#wildmenu_renderer(...)
  let l:args = a:0 > 0 ? a:1 : {}

  if !has_key(l:args, 'mode')
    let l:args.mode = has('nvim-0.4') ? 'float' : 'statusline'
  endif

  if l:args.mode ==# 'float'
    return wilder#renderer#wildmenu_float#make(l:args)
  endif

    return wilder#renderer#wildmenu_statusline#make(l:args)
endfunction

function! wilder#popupmenu_renderer(...)
  let l:args = get(a:, 1, {})
  return wilder#renderer#popupmenu#make(l:args)
endfunction

function! wilder#airline_theme(...)
  let l:args = get(a:000, 0, {})
  return wilder#renderer#wildmenu_theme#airline_theme(l:args)
endfunction

function! wilder#lightline_theme(...)
  let l:args = get(a:000, 0, {})
  return wilder#renderer#wildmenu_theme#lightline_theme(l:args)
endfunction

function! s:find_function_script_file(f)
  try
    " ensure function is autoloaded
    silent call eval(a:f . '()')
  catch /E119/
    " success
  catch
    return ''
  endtry

  let l:output = execute('verbose function ' . a:f)
  let l:lines = split(l:output, '\n')
  if len(l:lines) < 2
    return ''
  endif

  let l:matches = matchlist(l:lines[1], 'Last set from \(.\+\) line \d\+$')
  if len(l:matches) < 2
    " verbose function output is different for older versions.
    let l:matches = matchlist(l:lines[1], 'Last set from \(.\+\)$')
    if len(l:matches) < 2
      return ''
    endif
  endif

  return l:matches[1]
endfunction

let s:module_path_cache = wilder#cache#cache()

function! s:get_module_path(f, modify_path, use_cached)
  if !a:use_cached || !s:module_path_cache.has_key(a:f)
    let l:file = s:find_function_script_file(a:f)
    let l:path = empty(l:file) ?
          \ '' :
          \ simplify(l:file . a:modify_path)
    call s:module_path_cache.set(a:f, l:path)
  endif

  return s:module_path_cache.get(a:f)
endfunction

function! wilder#fruzzy_path(...) abort
  return s:get_module_path('fruzzy#version', '/../../rplugin/python3', get(a:, 1, 1))
endfunction

function! wilder#cpsm_path(...) abort
  return s:get_module_path('cpsm#CtrlPMatch', '/..', get(a:, 1, 1))
endfunction

let s:project_root_cache = wilder#cache#cache()

function! wilder#project_root(...) abort
  if a:0
    let l:root_markers = a:1
  else
    let l:root_markers = ['.hg', '.git']
  endif

  return {-> s:project_root(l:root_markers)}
endfunction

function! wilder#clear_project_root_cache() abort
  call s:project_root_cache.clear()
endfunction

function! s:project_root(root_markers, ...) abort
  if a:0
    let l:path = a:1
  else
    let l:path = getcwd()
  endif

  if !s:project_root_cache.has_key(l:path)
    let l:project_root = s:get_project_root(l:path, a:root_markers)
    call s:project_root_cache.set(l:path, l:project_root)
  endif

  return s:project_root_cache.get(l:path)
endfunction

function! s:get_project_root(path, root_markers) abort
  let l:home_directory = expand('~')
  let l:find_path = a:path . ';' . l:home_directory

  for l:root_marker in a:root_markers
    let l:result = findfile(l:root_marker, l:find_path)
    if empty(l:result)
      let l:result = finddir(l:root_marker, l:find_path)
    endif

    if empty(l:result)
      continue
    endif

    return fnamemodify(l:result, ':~:h')
  endfor

  return ''
endfunction
