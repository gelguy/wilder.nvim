let s:cmdline_cache = wilder#cache#mru_cache(30)

function! wilder#cmdline#parse(cmdline) abort
  if !s:cmdline_cache.has_key(a:cmdline)
    let l:ctx = {'cmdline': a:cmdline, 'pos': 0, 'cmd': '', 'expand': ''}
    call wilder#cmdline#main#do(l:ctx)

    let l:ctx['arg'] = l:ctx['cmdline'][l:ctx.pos :]
    let l:ctx['pos'] = l:ctx.pos
    call s:cmdline_cache.set(a:cmdline, l:ctx)
  endif

  return copy(s:cmdline_cache.get(a:cmdline))
endfunction

" match_arg  : the argument for the fuzzy filter to match against
" expand_arg : the argument passed to getcompletion()
" expand     : the type passed to getcompletion()
" fuzzy_char : the character used to get fuzzy completion if fuzzy mode is 1
function! wilder#cmdline#prepare_getcompletion(ctx, res, fuzzy) abort
  let a:res.match_arg = a:res.arg
  let a:res.expand_arg = has_key(a:res, 'subcommand_start')
        \ ? a:res.cmdline[a:res.subcommand_start :]
        \ : a:res.arg

  if !a:fuzzy
    return a:res
  endif

  return s:prepare_fuzzy_completion(a:ctx, a:res)
endfunction

" Sets match_arg, expand_arg fuzzy_char based on expand and expand_arg.
" Generally we want to use the first char in expand_arg as fuzzy_char,
" set match_arg to expand_arg, and adjust expand_arg to '' since we are only
" expanding the fuzzy char.
function! s:prepare_fuzzy_completion(ctx, res) abort
  " if argument is empty, use normal completions
  " only up to 300 tags are returned, don't fuzzy match for 'help'
  if a:res.pos == len(a:res.cmdline) ||
        \ a:res.expand ==# 'help'
    return a:res
  endif

  " only up to 300 tags are returned, don't fuzzy match for 'tag'
  if a:res.expand ==# 'tags' ||
        \ a:res.expand ==# 'tags_listfiles'
    " if tag-regexp, prevent filtering by removing match_arg
    if a:res.expand_arg[0] ==# '/'
      let a:res.match_arg = ''
    endif

    return a:res
  endif

  if (a:res.expand ==# 'expression' || a:res.expand ==# 'var') &&
        \ a:res.expand_arg[1] ==# ':' &&
        \ (a:res.expand_arg[0] ==# 'g' || a:res.expand_arg[0] ==# 's')
    let l:prefix = a:res.expand_arg[0: 1]
    let l:fuzzy_char = a:res.expand_arg[2]
    let a:res.match_arg = a:res.expand_arg[2 :]
  elseif a:res.expand ==# 'mapping'
    " Special keys such as <Space> cannot be fuzzy completed since < will not
    " get completions for <Space>. A workaround is to return all mappings and
    " let the fuzzy filter remove the non-matching candidates.
    let l:prefix = ''
    let l:fuzzy_char = ''
    let a:res.match_arg = a:res.expand_arg
  elseif a:res.expand ==# 'buffer'
    " getcompletion() for buffers checks against the file name, but we want to
    " check against the full path. Return all buffers and let the fuzzy filter
    " remove the non-matching candidates.
    let l:prefix = ''
    let l:fuzzy_char = ''
    let a:res.match_arg = a:res.expand_arg
  else
    let l:prefix = ''
    let l:fuzzy_char = strcharpart(a:res.expand_arg, 0, 1)
  endif

  let a:res.expand_arg = l:prefix
  let a:res.fuzzy_char = l:fuzzy_char
  return a:res
endfunction

function! wilder#cmdline#prepare_file_completion(ctx, res, fuzzy)
  let l:res = copy(a:res)
  let l:arg = l:res.arg

  let l:slash = !has('win32') && !has('win64')
        \ ? '/'
        \ : &shellslash
        \ ? '/'
        \ : '\'

  " Special handling for ~. Return the home directory.
  if l:arg ==# '~'
    let l:res.fuzzy_char = ''
    let l:res.expand_arg = ''
    let l:res.completions = [expand('~') . l:slash]

    return l:res
  endif

  let l:original_len = len(l:arg)

  " Expand the fnamemodify()-able part, if any.
  " ^(%|#|<cword>|<cWORD>|<client>)(:[phtre])*
  let l:matches = matchlist(l:arg,
        \ '^\(%\|#\|<cword>|<cWORD>|<client>\)' .
        \ '\(\%(:[phtre]\)*\)')
  if len(l:matches) > 0
    let l:part_to_fnamemodify = l:matches[0]
    let l:rest = l:arg[len(l:part_to_fnamemodify) :]
    let l:arg = expand(l:part_to_fnamemodify) . l:rest

    " The full path was expanded, show the expanded path here.
    if empty(l:rest)
      let l:res.fuzzy_char = ''
      let l:res.expand_arg = ''
      let l:res.completions = [l:arg]

      return l:res
    endif

    " Adjust current directory to empty string.
    if l:arg ==# '.'
      let l:arg = ''
    endif
  endif

  let l:allow_backslash = has('win32') || has('win64')

  " Pattern for matching directory separator.
  if !l:allow_backslash
    let l:dir_sep = l:slash
  else
    if l:slash ==# '\'
      let l:dir_sep = '\\'
    else
      let l:dir_sep = '/\|\\'
    endif
  endif

  " Handle wildcards.
  let l:first_wildcard = match(l:arg, '\*')
  if l:first_wildcard >= 0
    if l:first_wildcard > 0
      " Expand the portion before the wildcard since expand('foo/*') will glob
      " for matches.
      let l:before_wildcard = l:arg[: l:first_wildcard - 1]
      let l:after_wildcard = l:arg[l:first_wildcard :]

      let l:expand_arg = expand(l:before_wildcard) . l:after_wildcard
    else
      let l:expand_arg = l:arg
    endif

    " Don't use fuzzy matching for wildcards.
    let l:res.has_wildcard = 1
    let l:res.match_arg = ''
    let l:res.expand_arg = l:expand_arg

    return l:res
  endif

  " Split path into head and tail
  if match(l:arg, l:dir_sep) >= 0
    let l:head = fnamemodify(l:arg, ':h')
    let l:tail = fnamemodify(l:arg, ':t')
  else
    let l:head = ''
    let l:tail = l:arg
  endif

  " Check if tail is trying to complete an env var.
  let l:matches = matchlist(l:tail, '\$\(\f*\)$')
  if len(l:matches) >= 2
    let l:env_var = l:matches[1]
    let l:path_prefix = l:arg[:-len(l:env_var)-1]

    let l:res.path_prefix = l:path_prefix
    let l:res.expand = 'environment'
    let l:res.expand_arg = ''
    let l:res.fuzzy_char = ''
    let l:res.completions = map(getcompletion(l:env_var, 'environment'),
          \ {_, x -> l:path_prefix . x})

    " Get position of the $ in tail.
    let l:dollar_pos = len(l:tail) - len(l:env_var)

    " Show cursor after the $.
    let l:res.pos += l:original_len - len(l:tail) + l:dollar_pos

    return l:res
  endif

  " Append / back to l:head.
  if !empty(l:head) && l:head !=# l:slash
    let l:old_len = len(l:head)

    let l:head = expand(l:head) . l:slash
  endif

  let l:res.match_arg = l:tail

  " Don't trim leading / for absolute paths when drawing.
  let l:path_prefix = l:head ==# l:slash ? '' : l:head

  " If arg starts with ~/, show paths relative to ~.
  if l:arg[0] ==# '~' && match(l:arg[1], l:dir_sep) == 0
    let l:res.relative_to_home_dir = 1
    let l:res.path_prefix = fnamemodify(l:path_prefix, ':~')
  else
    let l:res.path_prefix = l:path_prefix
  endif

  if a:fuzzy
    let l:res.expand_arg = l:head
    let l:res.fuzzy_char = strcharpart(l:tail, 0, 1)
  else
    let l:res.expand_arg = l:head . l:tail
    let l:res.fuzzy_char = ''
  endif

  if !empty(l:head)
    " Show cursor at the start of tail.
    let l:res.pos += l:original_len - len(l:tail)
  endif

  return l:res
endfunction

function! wilder#cmdline#fuzzy_filt(ctx, candidates, query) abort
  if empty(a:query)
    return a:candidates
  endif

  " make fuzzy regex
  let l:split_query = split(a:query, '\zs')
  let l:i = 0
  let l:regex = '\V'
  while l:i < len(l:split_query)
    if l:i > 0
      let l:regex .= '\.\{-}'
    endif

    let l:c = l:split_query[l:i]

    if l:c ==# '\'
      let l:regex .= '\\'
    elseif l:c ==# toupper(l:c)
      let l:regex .= l:c
    else
      let l:regex .= '\%(' . l:c . '\|' . toupper(l:c) . '\)'
    endif

    let l:i += 1
  endwhile

  return filter(copy(a:candidates), {_, x -> match(x, l:regex) != -1})
endfunction

function! s:make_python_fuzzy_regex(query)
  let l:split_query = split(a:query, '\zs')

  let l:regex = ''
  let l:i = 0
  while l:i < len(l:split_query)
    if l:i > 0
      let l:regex .= '.*?'
    endif

    let l:c = l:split_query[l:i]

    if l:c ==# '\' ||
          \ l:c ==# '.' ||
          \ l:c ==# '^' ||
          \ l:c ==# '$' ||
          \ l:c ==# '*' ||
          \ l:c ==# '+' ||
          \ l:c ==# '?' ||
          \ l:c ==# '|' ||
          \ l:c ==# '(' ||
          \ l:c ==# ')' ||
          \ l:c ==# '{' ||
          \ l:c ==# '}' ||
          \ l:c ==# '[' ||
          \ l:c ==# ']'
      let l:regex .= '(\' . l:c . ')'
    elseif l:c ==# toupper(l:c)
      let l:regex .= '(' . l:c . ')'
    else
      let l:regex .= '(' . l:c . '|' . toupper(l:c) . ')'
    endif

    let l:i += 1
  endwhile

  return l:regex
endfunction

function! wilder#cmdline#python_fuzzy_filt(ctx, opts, candidates, query) abort
  if empty(a:query)
    return a:candidates
  endif

  let l:regex = s:make_python_fuzzy_regex(a:query)

  return {ctx -> _wilder_python_fuzzy_filt(ctx, a:opts, a:candidates, l:regex)}
endfunction

function! wilder#cmdline#python_fruzzy_filt(ctx, opts, candidates, query) abort
  if empty(a:query)
    return a:candidates
  endif

  return {ctx -> _wilder_python_fruzzy_filt(ctx, a:opts, a:candidates, a:query)}
endfunction

function! wilder#cmdline#python_cpsm_filt(ctx, opts, candidates, query) abort
  if empty(a:query)
    return a:candidates
  endif

  return {ctx -> _wilder_python_cpsm_filt(ctx, a:opts, a:candidates, a:query)}
endfunction

function! wilder#cmdline#get_fuzzy_completion(ctx, res, getcompletion, fuzzy_mode) abort
  " if argument is empty, use normal completions
  " don't fuzzy complete for help since a maximum of 300 help tags are returned
  " don't fuzzy complete for tag-regexp
  if a:res.pos == len(a:res.cmdline) ||
        \ a:res.expand ==# 'help' ||
        \ a:res.expand ==# 'tags' ||
        \ a:res.expand ==# 'tags_listfiles'
    return a:getcompletion(a:ctx, a:res)
  endif

  if a:fuzzy_mode == 2
    let l:fuzzy_char = ''
  else
    let l:fuzzy_char = get(a:res, 'fuzzy_char', '')
  endif

  if toupper(l:fuzzy_char) ==# l:fuzzy_char
    let a:res.expand_arg = a:res.expand_arg . l:fuzzy_char
    return a:getcompletion(a:ctx, a:res)
  endif

  let l:lower_res = copy(a:res)
  let l:lower_res.expand_arg = a:res.expand_arg . l:fuzzy_char

  let l:upper_res = copy(a:res)
  let l:upper_res.expand_arg = a:res.expand_arg . toupper(l:fuzzy_char)

  return wilder#wait(a:getcompletion(a:ctx, l:upper_res),
        \ {ctx, upper_xs -> wilder#resolve(ctx, wilder#wait(a:getcompletion(ctx, l:lower_res),
        \ {ctx, lower_xs -> wilder#resolve(ctx, wilder#uniq_filt(0, 0, lower_xs + upper_xs))}))})
endfunction

function! wilder#cmdline#python_get_file_completion(ctx, res) abort
  if has_key(a:res, 'completions')
    return a:res['completions']
  endif

  let l:expand_arg = a:res.expand_arg

  if a:res.expand ==# 'dir' ||
        \ a:res.expand ==# 'file' ||
        \ a:res.expand ==# 'file_in_path' ||
        \ a:res.expand ==# 'shellcmd'
    return {ctx -> _wilder_python_get_file_completion(
          \ ctx,
          \ l:expand_arg,
          \ a:res.expand,
          \ get(a:res, 'has_wildcard', 0),
          \ get(a:res, 'path_prefix', ''),
          \ )}
  endif

  if a:res.expand ==# 'user'
    return {ctx -> _wilder_python_get_users(ctx, l:expand_arg, a:res.expand)}
  endif

  return []
endfunction

function! wilder#cmdline#getcompletion(ctx, res) abort
  let l:expand_arg = a:res.expand_arg

  " getting all shellcmds takes a significant amount of time
  if a:res.expand ==# 'shellcmd' && empty(l:expand_arg)
    return []
  endif

  if a:res.expand ==# 'dir' ||
        \ a:res.expand ==# 'file' ||
        \ a:res.expand ==# 'file_in_path' ||
        \ a:res.expand ==# 'shellcmd'

    if get(a:res, 'has_wildcard', 0)
      let l:xs = expand(l:expand_arg, 0, 1)

      if len(l:xs) == 1 && l:xs[0] ==# l:expand_arg
        return []
      endif

      return l:xs
    endif

    return getcompletion(l:expand_arg, a:res.expand, 1)
  endif

  if a:res.expand ==# 'nothing' || a:res.expand ==# 'unsuccessful'
    return []
  elseif a:res.expand ==# 'augroup'
    return getcompletion(l:expand_arg, 'augroup')
  elseif a:res.expand ==# 'arglist'
    return getcompletion(l:expand_arg, 'arglist')
  elseif a:res.expand ==# 'behave'
    return getcompletion(l:expand_arg, 'behave')
  elseif a:res.expand ==# 'buffer'
    let l:buffers = getcompletion(l:expand_arg, 'buffer')
    let l:buffers = map(l:buffers, {_, x -> fnamemodify(x, ':~:.')})

    let l:alt_file = expand('#')
    if !empty(l:alt_file)
      let l:alt_file = fnamemodify(l:alt_file, ':~:.')
      let l:i = index(l:buffers, l:alt_file)

      if l:i > 0
        let l:buffers = [l:buffers[l:i]] + l:buffers[0 : l:i-1] + l:buffers[l:i+1 :]
      endif
    endif

    return l:buffers
  elseif a:res.expand ==# 'checkhealth'
    return has('nvim') ? getcompletion(l:expand_arg, 'checkhealth') : []
  elseif a:res.expand ==# 'color'
    return getcompletion(l:expand_arg, 'color')
  elseif a:res.expand ==# 'command'
    return getcompletion(l:expand_arg, 'command')
  elseif a:res.expand ==# 'compiler'
    return getcompletion(l:expand_arg, 'compiler')
  elseif a:res.expand ==# 'cscope'
    return getcompletion(a:res.cmdline[a:res.subcommand_start :], 'cscope')
  elseif a:res.expand ==# 'event'
    return getcompletion(l:expand_arg, 'event')
  elseif a:res.expand ==# 'expression'
    return getcompletion(l:expand_arg, 'expression')
  elseif a:res.expand ==# 'environment'
    return getcompletion(l:expand_arg, 'environment')
  elseif a:res.expand ==# 'function'
    return getcompletion(l:expand_arg, 'function')
  elseif a:res.expand ==# 'help'
    return getcompletion(l:expand_arg, 'help')
  elseif a:res.expand ==# 'highlight'
    return getcompletion(l:expand_arg, 'highlight')
  elseif a:res.expand ==# 'history'
    return getcompletion(l:expand_arg, 'history')
  elseif a:res.expand ==# 'language'
    return getcompletion(l:expand_arg, 'locale') +
          \ filter(['ctype', 'messages', 'time'], {_, x -> match(x, l:expand_arg) == 0})
  elseif a:res.expand ==# 'locale'
    return getcompletion(l:expand_arg, 'locale')
  elseif a:res.expand ==# 'mapping'
    let l:map_args = get(a:res, 'map_args', {})

    let l:result = []

    if l:expand_arg ==# '' || l:expand_arg[0] ==# '<'
      for l:map_arg in ['<buffer>', '<unique>', '<nowait>', '<silent>',
            \ '<special>', '<script>', '<expr>']
        if !has_key(l:map_args, l:map_arg)
          call add(l:result, l:map_arg)
        endif
      endfor

      if l:expand_arg[0] ==# '<'
        call filter(l:result, {_, x -> match(x, l:expand_arg) == 0})
      endif
    endif

    if a:res.cmd[-5 :] ==# 'unmap'
      let l:mode = a:res.cmd ==# 'unmap' ? '' : a:res.cmd[0]
      let l:cmd = 'map'
    elseif a:res.cmd[-3 :] ==# 'map'
      let l:mode = a:res.cmd ==# 'map' || a:res.cmd ==# 'noremap' ? '' : a:res.cmd[0]
      let l:cmd = 'map'
    elseif a:res.cmd[-12 :] ==# 'unabbreviate'
      let l:mode = a:res.cmd ==# 'unabbreviate' ? '' : a:res.cmd[0]
      let l:cmd = 'abbrev'
    elseif a:res.cmd ==# 'abbreviate'
      let l:mode = ''
      let l:cmd = 'abbrev'
    elseif a:res.cmd[-6 :] ==# 'abbrev'
      let l:mode = a:res.cmd ==# 'noreabbrev' ? '' : a:res.cmd[0]
      let l:cmd = 'abbrev'
    else
      let l:mode = ''
      let l:cmd = 'map'
    endif

    let l:lines = split(execute(l:mode . l:cmd . ' ' . join(keys(l:map_args), ' ') .
          \ ' ' . l:expand_arg), "\n")

    if len(l:lines) != 1 ||
          \ (l:lines[0] !=# 'No mapping found' &&
          \ l:lines[0] !=# 'No abbreviation found')
      for l:line in l:lines
        let l:words = split(l:line,'\s\+')
        if l:line[0] ==# ' '
          let l:map_lhs = l:words[0]
        else
          let l:map_lhs = l:words[1]
        endif

        call add(l:result, l:map_lhs)
      endfor
    endif

    return wilder#uniq_filt(0, 0, l:result)
  elseif a:res.expand ==# 'mapclear'
    return match('<buffer>', l:expand_arg) == 0 ? ['<buffer>'] : []
  elseif a:res.expand ==# 'menu'
    if !has_key(a:res, 'menu_arg')
      return []
    endif
    return getcompletion(a:res.menu_arg, 'menu')
  elseif a:res.expand ==# 'messages'
    return getcompletion(l:expand_arg, 'messages')
  elseif a:res.expand ==# 'option'
    return getcompletion(l:expand_arg, 'option')
  elseif a:res.expand ==# 'option_bool'
    return filter(wilder#cmdline#set#get_bool_options(),
          \ {_, x -> match(x, l:expand_arg == 0)})
  elseif a:res.expand ==# 'option_old'
    let l:old_option = eval('&' . a:res.option)
    return [type(l:old_option) is v:t_string ? l:old_option : string(l:old_option)]
  elseif a:res.expand ==# 'packadd'
    return getcompletion(l:expand_arg, 'packadd')
  elseif a:res.expand ==# 'profile'
    return filter(['continue', 'dump', 'file', 'func', 'pause', 'start'],
          \ {_, x -> match(x, l:expand_arg) == 0})
  elseif a:res.expand ==# 'ownsyntax'
    return getcompletion(l:expand_arg, 'syntax')
  elseif a:res.expand ==# 'shellcmd'
    return getcompletion(l:expand_arg, 'shellcmd')
  elseif a:res.expand ==# 'sign'
    return getcompletion(a:res.cmdline[a:res.subcommand_start :], 'sign')
  elseif a:res.expand ==# 'syntax'
    return getcompletion(l:expand_arg, 'syntax')
  elseif a:res.expand ==# 'syntime'
    return getcompletion(l:expand_arg, 'syntime')
  elseif a:res.expand ==# 'user'
    return getcompletion(l:expand_arg, 'user')
  elseif a:res.expand ==# 'user_func'
    let l:functions = getcompletion(l:expand_arg, 'function')
    let l:functions = filter(l:functions, {_, x -> !(x[0] >= 'a' && x[0] <= 'z')})
    return map(l:functions, {_, x -> x[-1 :] ==# ')' ? x[: -3] : x[: -2]})
  elseif a:res.expand ==# 'user_addr_type'
    return filter(['arguments', 'buffers', 'lines', 'loaded_buffers',
          \ 'quickfix', 'tabs', 'windows'], {_, x -> match(x, l:expand_arg) == 0})
  elseif a:res.expand ==# 'user_cmd_flags'
    return filter(['addr', 'bar', 'buffer', 'complete', 'count',
          \ 'nargs', 'range', 'register'], {_, x -> match(x, l:expand_arg) == 0})
  elseif a:res.expand ==# 'user_complete'
    return filter(['arglist', 'augroup', 'behave', 'buffer', 'checkhealth',
          \ 'color', 'command', 'compiler', 'cscope', 'custom',
          \ 'customlist', 'dir', 'environment', 'event', 'expression',
          \ 'file', 'file_in_path', 'filetype', 'function', 'help',
          \ 'highlight', 'history', 'locale', 'mapclear', 'mapping',
          \ 'menu', 'messages', 'option', 'packadd', 'shellcmd',
          \ 'sign', 'syntax', 'syntime', 'tag', 'tag_listfiles',
          \ 'user', 'var'], {_, x -> match(x, l:expand_arg) == 0})
  elseif a:res.expand ==# 'user_nargs'
    if empty(l:expand_arg)
      return ['*', '+', '0', '1', '?']
    endif

    if l:expand_arg ==# '*' || l:expand_arg ==# '+' || l:expand_arg ==# '0' ||
          \ l:expand_arg ==# '1' || l:expand_arg ==# '?'
      return [l:expand_arg]
    endif

    return []
  elseif a:res.expand ==# 'user_commands'
    return filter(getcompletion(l:expand_arg, 'command'), {_, x -> !(x[0] >= 'a' && x[0] <= 'z')})
  elseif a:res.expand ==# 'tags' ||
        \ a:res.expand ==# 'tags_listfiles'
    " tags_listfiles is only used for c_CTRL-D
    " both return the same result for getcompletion()
    return getcompletion(l:expand_arg, 'tag')
  elseif a:res.expand ==# 'var'
    return getcompletion(l:expand_arg, 'var')
  endif

  " fallback to cmdline getcompletion
  if has('nvim')
    return getcompletion(a:res.cmdline, 'cmdline')
  endif

  return []
endfunction

function! wilder#cmdline#is_file_expansion(expand) abort
  return a:expand ==# 'file' ||
        \ a:expand ==# 'file_in_path' ||
        \ a:expand ==# 'dir' ||
        \ a:expand ==# 'shellcmd' ||
        \ a:expand ==# 'user'
endfunction

function! wilder#cmdline#is_user_command(cmd) abort
  return !empty(a:cmd) && a:cmd[0] >=# 'A' && a:cmd[0] <=# 'Z'
endfunction

" returns [{handled}, {result}, [{res}]]
function! wilder#cmdline#prepare_user_completion(ctx, res) abort
  if !wilder#cmdline#is_user_command(a:res.cmd)
    return [0, a:res]
  endif

  if !has('nvim')
    return [1, v:true, a:res]
  endif

  let l:user_commands = nvim_get_commands({})

  if !has_key(l:user_commands, a:res.cmd)
    return [1, v:false, a:res]
  endif

  let l:user_command = l:user_commands[a:res.cmd]

  if has_key(l:user_command, 'complete_arg') &&
        \ l:user_command.complete_arg isnot v:null
    try
      " Function might be script-local or point to script-local variables.
      let l:Completion_func = function(l:user_command.complete_arg)
      let l:result = l:Completion_func(a:res.arg, a:res.cmdline, len(a:res.cmdline))
    catch
      let l:res = copy(a:res)
      let l:res.pos = 0
      return [1, v:true, l:res]
    endtry

    if get(l:user_command, 'complete', '') ==# 'custom'
      let l:result = split(l:result, '\n')
      let l:result = filter(l:result, {i, x -> match(x, l:res.arg) != -1})
    endif

    let l:res = copy(a:res)
    let l:res.match_arg = l:res.cmdline[l:res.pos :]
    return [1, l:result, l:res]
  endif

  if has_key(l:user_command, 'complete') &&
        \ l:user_command['complete'] isnot v:null &&
        \ l:user_command['complete'] !=# 'custom' &&
        \ l:user_command['complete'] !=# 'customlist'
    let l:res = copy(a:res)
    let l:res['expand'] = l:user_command['complete']

    return [0, l:res]
  endif

  return [1, v:false, a:res]
endfunction

function! wilder#cmdline#replace(ctx, x, data) abort
  let l:result = wilder#cmdline#parse(a:ctx.cmdline)

  if l:result.pos == 0
    return a:x
  endif

  return l:result.cmdline[: l:result.pos - 1] . a:x
endfunction

function! wilder#cmdline#draw_path(ctx, x, data) abort
  let l:path_prefix = get(a:data, 'cmdline.path_prefix', '')
  return a:x[len(l:path_prefix) :]
endfunction

function! s:convert_result_to_data(res)
  let l:data = {
        \ 'pos': a:res.pos,
        \ 'cmdline.command': a:res.cmd,
        \ 'cmdline.expand': a:res.expand,
        \ 'cmdline.arg': a:res.arg,
        \ }

  if has_key(a:res, 'path_prefix')
    let l:data['cmdline.path_prefix'] = a:res.path_prefix
  endif

  if has_key(a:res, 'match_arg')
    let l:data['cmdline.match_arg'] = a:res.match_arg
  endif

  if has_key(a:res, 'has_wildcard')
    let l:data['cmdline.has_wildcard'] = a:res.has_wildcard
  endif

  return l:data
endfunction

function! s:getcompletion(ctx, res, fuzzy, use_python, is_file_expansion) abort
  let l:Completion_func = a:use_python && a:is_file_expansion
        \ ? funcref('wilder#cmdline#python_get_file_completion')
        \ : funcref('wilder#cmdline#getcompletion')

  if a:fuzzy
    let l:Getcompletion = {ctx, x -> wilder#cmdline#get_fuzzy_completion(
          \ ctx, x, l:Completion_func, a:fuzzy)}
  else
    let l:Getcompletion = l:Completion_func
  endif

  return wilder#wait(l:Getcompletion(a:ctx, a:res),
        \ {ctx, xs -> wilder#resolve(ctx, {
        \ 'value': xs,
        \ 'pos': a:res.pos,
        \ 'data': s:convert_result_to_data(a:res),
        \ })})
endfunction

function wilder#cmdline#should_use_file_finder(res) abort
  if has_key(a:res, 'completions')
    return v:false
  endif

  let l:arg = a:res.arg

  if match(l:arg, '\*') != -1
    return 0
  endif

  if l:arg[0] ==# '%' ||
        \ l:arg[0] ==# '#' ||
        \ l:arg[0] ==# '<'
    return 0
  endif

  let l:path = a:res.expand_arg

  " ./. simplifies to .
  if l:path ==# './.' ||
        \ l:path ==# '.\.'
    return 0
  endif

  let l:path = simplify(l:path)

  if l:path[0] ==# '~' ||
        \ l:path[0] ==# '/' ||
        \ l:path[0] ==# '\' ||
        \ l:path[0:1] ==# '..' ||
        \ l:path[0:1] ==# './' ||
        \ l:path[0:1] ==# '.\'
    return 0
  endif

  if has('win32') || has('win64')
    return l:path[1] !=# ':'
  endif

  return 1
endfunction

function! wilder#cmdline#python_file_finder_pipeline(opts) abort
  let l:opts = copy(a:opts)

  let l:should_debounce = get(l:opts, 'debounce', 0) > 0
  if l:should_debounce
    let l:debounce_interval = l:opts['debounce']
    let l:Debounce = wilder#debounce(l:debounce_interval)
  endif

  if has_key(l:opts, 'filters')
    let l:checked_filters = []

    for l:filter in l:opts['filters']
      if type(l:filter) isnot v:t_dict
        let l:filter = {'name': l:filter}
      endif

      let l:filter_opts = get(l:filter, 'opts', {})
      let l:filter['opts'] = l:filter_opts

      if l:filter['name'] ==# 'fruzzy_filter' &&
            \ !has_key(l:filter_opts, 'fruzzy_path')
        let l:filter_opts['fruzzy_path'] = wilder#fruzzy_path()
      endif

      if l:filter['name'] ==# 'cpsm_filter' &&
            \ !has_key(l:filter_opts, 'cpsm_path')
        let l:filter_opts['cpsm_path'] = wilder#cpsm_path()
      endif

      call add(l:checked_filters, l:filter)
    endfor

    let l:opts['filters'] = l:checked_filters
  endif

  if has_key(l:opts, 'path')
    let l:Path = l:opts['path']

    if type(l:Path) isnot v:t_func
      let l:Path_func = {-> l:Path}
    else
      let l:Path_func = l:Path
    endif
  else
    let l:Path_func = wilder#project_root()
  endif

  let l:pipeline = [
        \ wilder#check({-> getcmdtype() ==# ':'}),
        \ {_, x -> wilder#cmdline#parse(x)},
        \ wilder#check({_, res -> res.expand ==# 'file' || res.expand ==# 'dir'}),
        \ wilder#subpipeline({ctx, res1 -> [
        \   {ctx, res1 -> wilder#cmdline#prepare_file_completion(ctx, copy(res1), 0)},
        \   {ctx, res2 -> extend(res2, {'pos': res1.pos})},
        \ ]}),
        \ wilder#check({ctx, res -> wilder#cmdline#should_use_file_finder(res)}),
        \ ] + (l:should_debounce ? [l:Debounce] : []) + [
        \ wilder#subpipeline({ctx, res -> [
        \   {-> {ctx -> _wilder_python_file_finder(
        \     ctx, l:opts, getcwd(), l:Path_func(ctx, res),
        \     expand(simplify(res.arg)), res.expand ==# 'dir')
        \   }},
        \   wilder#result({
        \     'pos': res.pos,
        \     'replace': ['wilder#cmdline#replace'],
        \     'data': extend(s:convert_result_to_data(res), {'query': expand(simplify(res.arg))}),
        \   }),
        \ ]}),
        \ ]

  return l:pipeline
endfunction

function! wilder#cmdline#getcompletion_pipeline(opts) abort
  let l:use_python = get(a:opts, 'use_python', has('nvim'))

  let l:fuzzy = get(a:opts, 'fuzzy', 0)
  if l:fuzzy
    if has_key(a:opts, 'fuzzy_filter')
      let l:Filter = a:opts['fuzzy_filter']
    elseif l:use_python
      let l:Filter = wilder#python_fuzzy_filter()
    else
      let l:Filter = wilder#fuzzy_filter()
    endif
  endif

  let l:file_completion_subpipeline = [
        \ wilder#check({_, res -> wilder#cmdline#is_file_expansion(res.expand)}),
        \ {ctx, res -> wilder#cmdline#prepare_file_completion(ctx, res, l:fuzzy)},
        \ wilder#subpipeline({ctx, res -> [
        \   {ctx, res -> s:getcompletion(ctx, res, l:fuzzy, l:use_python, 1)},
        \ ] + (get(res, 'relative_to_home_dir', 0) ?
        \   [wilder#result({
        \     'value': {ctx, xs -> map(xs, {i, x -> fnamemodify(x, ':~')})},
        \   })] : [])
        \ }),
        \ ]

  if l:fuzzy
    let l:File_fuzzy_filter = wilder#result({
          \ 'value': {ctx, xs, data -> l:Filter(
          \   ctx, xs, get(data, 'cmdline.path_prefix', '') . get(data, 'cmdline.match_arg', '')
          \ )}})
    call add(l:file_completion_subpipeline, l:File_fuzzy_filter)
  endif

  call add(l:file_completion_subpipeline, wilder#result({
        \ 'output': [{_, x -> escape(x, ' ')}],
        \ 'draw': ['wilder#cmdline#draw_path'],
        \ }))

  let l:completion_subpipeline = [
        \ {ctx, res -> wilder#cmdline#prepare_getcompletion(ctx, res, l:fuzzy)},
        \ {ctx, res -> s:getcompletion(ctx, res, l:fuzzy, l:use_python, 0)},
        \ ]

  if l:fuzzy
    let l:Fuzzy_filter = wilder#result({
          \ 'value': {ctx, xs, data -> l:Filter(
          \   ctx, xs, get(data, 'cmdline.match_arg', '')
          \ )}})
    call add(l:completion_subpipeline, l:Fuzzy_filter)
  endif

  return [
        \ wilder#branch(
        \   l:file_completion_subpipeline,
        \   l:completion_subpipeline,
        \ ),
        \ wilder#result({
        \   'replace': ['wilder#cmdline#replace'],
        \ }),
        \ ]
endfunction

let s:substitute_commands = {
      \ 'substitute': v:true,
      \ 'smagic': v:true,
      \ 'snomagic': v:true,
      \ 'global': v:true,
      \ 'vglobal': v:true,
      \ }

function! wilder#cmdline#is_substitute_command(cmd) abort
  return has_key(s:substitute_commands, a:cmd)
endfunction

function! wilder#cmdline#substitute_pipeline(opts) abort
  let l:pipeline = [
      \ wilder#check({-> getcmdtype() ==# ':'}),
      \ {_, x -> wilder#cmdline#parse(x)},
      \ ]

  let l:search_pipeline = [
        \ wilder#check({_, res -> wilder#cmdline#is_substitute_command(res.cmd)}),
        \ ]

  if has_key(a:opts, 'hide_in_replace')
    let l:hide_in_replace = a:opts.hide_in_replace
  elseif has_key(a:opts, 'hide')
    " DEPRECATED: use hide_in_replace
    let l:hide_in_replace = a:opts.hide
  else
    let l:hide_in_replace = has('nvim') && !has('nvim-0.3.7')
  endif

  if l:hide_in_replace
    let l:search_pipeline += [{_, res -> len(res.substitute_args) == 2 ?
          \ res.substitute_args[1] : v:true}]
  else
    let l:search_pipeline += [{_, res -> len(res.substitute_args) == 2 ?
          \ res.substitute_args[1] : v:false}]
  endif

  if has_key(a:opts, 'pipeline')
    let l:search_pipeline += a:opts['pipeline']
  elseif has('nvim')
    let l:search_pipeline += wilder#python_search_pipeline({'skip_cmdtype_check': 1})
  else
    let l:search_pipeline += wilder#vim_search_pipeline({'skip_cmdtype_check': 1})
  endif

  call add(l:pipeline, wilder#subpipeline({ctx, res -> l:search_pipeline + [
        \ wilder#result({
        \   'data': {
        \     'cmdline.command': res.cmd,
        \   },
        \   'pos': res.pos + 1,
        \   'replace': ['wilder#cmdline#replace'],
        \ })]}))

  return l:pipeline
endfunction

function! wilder#cmdline#pipeline(opts) abort
  let l:pipeline = [
        \ wilder#check({-> getcmdtype() ==# ':'}),
        \ ]

  if has_key(a:opts, 'hide_in_substitute')
    let l:hide_in_substitute = a:opts.hide_in_substitute
  elseif has_key(a:opts, 'hide')
    " DEPRECATED: use hide_in_substitute
    let l:hide_in_substitute = a:opts.hide
  else
    let l:hide_in_substitute = has('nvim') && !has('nvim-0.3.7')
  endif

  call add(l:pipeline, {_, x -> wilder#cmdline#parse(x)})

  if l:hide_in_substitute
    call add(l:pipeline, {ctx, res -> len(get(res, 'substitute_args', [])) >= 2 ? v:true : res})
  endif

  call add(l:pipeline, {ctx, res -> wilder#cmdline#prepare_user_completion(ctx, res)})

  let l:getcompletion_pipeline = [{ctx, res -> res[1]}] +
        \ wilder#cmdline#getcompletion_pipeline(a:opts)

  let l:Sorter = get(a:opts, 'sorter', get(a:opts, 'sort', 0))
  if l:Sorter isnot 0
    call add(l:getcompletion_pipeline, wilder#result({
          \ 'value': {ctx, xs, data ->
          \   l:Sorter(ctx, xs, get(data, 'cmdline.match_arg', ''))}
          \ }))
  endif

  if get(a:opts, 'set_pcre2_pattern', 1)
    if get(a:opts, 'fuzzy', 0)
      call add(l:getcompletion_pipeline, wilder#result({
            \   'data': {ctx, data -> extend(data is v:null ? {} : data, {
            \     'pcre2.pattern': s:make_python_fuzzy_regex(get(data is v:null ? {} : data, 'cmdline.match_arg', ''))
            \   })},
            \ }))
    else
      call add(l:getcompletion_pipeline, wilder#result({
            \   'data': {ctx, data -> extend(data is v:null ? {} : data, {
            \     'pcre2.pattern': '(' .
            \         escape(get(data is v:null ? {} : data, 'cmdline.match_arg', ''), '\.^$*+?|(){}[]') . ')'
            \   })},
            \ }))
    endif
  endif

  call add(l:pipeline, wilder#branch(
        \ [
        \   {ctx, res -> res[0] ? res : v:false},
        \   wilder#subpipeline({ctx, res -> [
        \     {_, res -> res[1]},
        \     wilder#result({
        \       'pos': res[2].pos,
        \       'replace': ['wilder#cmdline#replace'],
        \       'data': s:convert_result_to_data(res[2]),
        \     }),
        \   ]}),
        \ ],
        \ l:getcompletion_pipeline,
        \ ))

  call add(l:pipeline, wilder#result({
        \   'data': {ctx, data -> extend(data is v:null ? {} : data, {
        \     'query': get(data is v:null ? {} : data, 'cmdline.match_arg', ''),
        \   })},
        \ }))

  return l:pipeline
endfunction
