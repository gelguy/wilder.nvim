function! wilder#highlighter#apply_first(highlighters)
  return {ctx, x, data -> s:apply_first(a:highlighters, ctx, x, data)}
endfunction

function! s:apply_first(highlighters, ctx, x, data)
  for l:Highlighter in a:highlighters
    let l:highlight = l:Highlighter(a:ctx, a:x, a:data)

    if l:highlight isnot 0
      return l:highlight
    endif
  endfor

  return 0
endfunction

function! wilder#highlighter#basic_highlighter(...)
  let l:opts = get(a:, 1, {})
  let l:language = get(l:opts, 'language', 'vim')

  if l:language ==# 'python'
    return {ctx, x, data -> wilder#highlighter#python_basic_highlight(ctx, l:opts, x, data)}
  endif

  return {ctx, x, data -> wilder#highlighter#vim_basic_highlight(ctx, l:opts, x, data)}
endfunction

function! wilder#highlighter#vim_basic_highlight(ctx, opts, x, data)
  if !has_key(a:data, 'query')
    return 0
  endif

  let l:query = a:data['query']
  let l:case_sensitive = get(a:opts, 'case_sensitive', 0)

  let l:split_str = split(a:x, '\zs')
  let l:split_query = split(l:query, '\zs')

  let l:spans = []
  let l:span = [-1, 0]

  let l:byte_pos = 0
  let l:i = 0
  let l:j = 0
  while l:i < len(l:split_str) && l:j < len(l:split_query)
    let l:str_len = strlen(l:split_str[l:i])

    if l:case_sensitive
      let l:match = l:split_str[l:i] ==# l:split_query[l:j]
    else
      let l:match = l:split_str[l:i] ==? l:split_query[l:j]
    endif

    if l:match
      let l:j += 1

      if l:span[0] == -1
        let l:span[0] = l:byte_pos
      endif

      let l:span[1] += l:str_len
    endif

    if !l:match && l:span[0] != -1
      call add(l:spans, l:span)
      let l:span = [-1, 0]
    endif

    let l:byte_pos += l:str_len
    let l:i += 1
  endwhile

  if l:span[0] != -1
    call add(l:spans, l:span)
  endif

  return l:spans
endfunction

function! wilder#highlighter#python_basic_highlight(ctx, opts, x, data)
  if !has_key(a:data, 'query')
    return 0
  endif

  let l:query = a:data['query']
  let l:case_sensitive = get(a:opts, 'case_sensitive', 0)

  return _wilder_python_basic_highlight(a:x, l:query, l:case_sensitive)
endfunction

function! wilder#highlighter#pcre2_highlighter(...)
  let l:opts = get(a:, 1, {})
  let l:language = get(l:opts, 'language', 'python')

  if l:language ==# 'lua'
    return {ctx, x, data -> wilder#highlighter#lua_pcre2_highlight(ctx, l:opts, x, data)}
  endif

  return {ctx, x, data -> wilder#highlighter#python_pcre2_highlight(ctx, l:opts, x, data)}
endfunction

function! wilder#highlighter#python_pcre2_highlight(ctx, opts, x, data)
  if !has_key(a:data, 'pcre2.pattern')
    return 0
  endif

  let l:pattern = a:data['pcre2.pattern']
  let l:engine = get(a:opts, 'engine', 're')

  return _wilder_python_pcre2_highlight(l:pattern, a:x, l:engine)
endfunction

function! wilder#highlighter#lua_pcre2_highlight(ctx, opts, x, data)
  if !has_key(a:data, 'pcre2.pattern')
    return 0
  endif

  let l:pattern = a:data['pcre2.pattern']

  return luaeval(
        \ 'require("wilder").pcre2_highlight(_A[1], _A[2])',
        \ [l:pattern, a:x])
endfunction

function! wilder#highlighter#python_cpsm_highlighter(...)
  let l:opts = get(a:, 1, {})
  return {ctx, x, data -> wilder#highlighter#python_highlight_cpsm(ctx, l:opts, x, data)}
endfunction

function! wilder#highlighter#python_highlight_cpsm(ctx, opts, x, data)
  if !has_key(a:data, 'query')
    return 0
  endif

  let l:query = a:data['query']

  let l:expand = get(a:data, 'cmdline.expand', '')
  let l:is_path = l:expand ==# 'file' ||
        \ l:expand ==# 'file_in_path' ||
        \ l:expand ==# 'dir' ||
        \ l:expand ==# 'shellcmd' ||
        \ l:expand ==# 'buffer'

  let l:opts = {
        \ 'ispath': l:is_path,
        \ 'cpsm_path': get(a:opts, 'cpsm_path', wilder#cpsm_path()),
        \ 'highlight_mode': get(a:opts, 'highlight_mode', 'basic'),
        \ }

  return _wilder_python_cpsm_highlight(l:opts, a:x, l:query)
endfunction

function! wilder#highlighter#lua_fzy_highlighter()
  return {ctx, x, data -> wilder#highlighter#lua_fzy_highlight(ctx, {}, x, data)}
endfunction

function! wilder#highlighter#lua_fzy_highlight(ctx, opts, x, data)
  if !has_key(a:data, 'query')
    return 0
  endif

  return luaeval(
        \ 'require("wilder").fzy_highlight(_A[1], _A[2])',
        \ [a:data.query, a:x])
endfunction

function! wilder#highlighter#tag_regexp_highlighter()
  return funcref('wilder#highlighter#tag_regexp_highlight')
endfunction

function! wilder#highlighter#tag_regexp_highlight(ctx, x, data)
  let l:expand = get(a:data, 'cmdline.expand', '')

  if l:expand !=# 'tags'
    return 0
  endif

  let l:arg = get(a:data, 'cmdline.arg', '')

  if l:arg[0] !=# '/'
    return 0
  endif

  let l:pattern = l:arg[1:]

  let l:start = match(a:x, l:pattern)
  if l:start == -1
    return []
  endif

  let l:matches = matchlist(a:x, l:arg[1:])
  if empty(l:matches)
    return []
  endif

  let l:len = strlen(l:matches[0])
  return [[l:start, l:len]]
endfunction
