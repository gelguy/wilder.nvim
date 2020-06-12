function! wilder#cmdline#parse(cmdline) abort
  if !exists('s:cache_cmdline') || a:cmdline !=# s:cache_cmdline
    let l:ctx = {'cmdline': a:cmdline, 'pos': 0, 'cmd': '', 'expand': ''}
    call wilder#cmdline#main#do(l:ctx)

    let s:cache_cmdline_result = l:ctx
    let s:cache_cmdline = a:cmdline
  endif

  return copy(s:cache_cmdline_result)
endfunction

function! wilder#cmdline#prepare_getcompletion(ctx, res, fuzzy) abort
  let a:res.match_arg = a:res.cmdline[a:res.pos :]
  let a:res.expand_arg = has_key(a:res, 'subcommand_start')
        \ ? a:res.cmdline[a:res.subcommand_start :]
        \ : a:res.cmdline[a:res.pos :]

  if !a:fuzzy
    return a:res
  endif

  return s:prepare_fuzzy_completion(a:ctx, a:res)
endfunction

function! s:prepare_fuzzy_completion(ctx, res) abort
  " if argument is empty, use normal completions
  " up to 300 help tags returned, so fuzzy matching does not work for 'help'
  if a:res.pos == len(a:res.cmdline) || a:res.expand ==# 'help'
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
  else
    let l:prefix = ''
    let l:fuzzy_char = a:res.expand_arg[0]
  endif

  let a:res.expand_arg = l:prefix
  let a:res.fuzzy_char = l:fuzzy_char
  return a:res
endfunction

function! wilder#cmdline#prepare_file_completion(ctx, res, fuzzy)
  let a:res.expand_arg = a:res.cmdline[a:res.pos :]
  let l:file_arg_start = a:res.pos

  let l:slash = !has('win32') && !has('win64')
        \ ? '/'
        \ : &shellslash
        \ ? '/'
        \ : '\'
  let l:allow_backslash = has('win32') || has('win64')

  let l:split_path = []
  let l:tail = ''
  let l:i = 0
  let l:no_fuzzy = 0
  let l:current_offset = 0
  let l:offset = 0

  " split path into path segments [...head] and tail
  " expands $env_vars in place
  " checks for wildcard
  while l:i < len(a:res.expand_arg)
    let l:char = a:res.expand_arg[l:i]

    if l:char ==# '\'
      if a:res.expand_arg[l:i + 1] ==# ' '
        let l:tail .= ' '
        let l:i += 2
        continue
      endif

      if l:allow_backslash
        call add(l:split_path, l:tail)
        let l:tail = ''
        let l:offset += l:current_offset
        let l:current_offset = 0
        let l:i += 1
        continue
      endif
    elseif l:char ==# '/'
      call add(l:split_path, l:tail)
      let l:tail = ''
      let l:offset += l:current_offset
      let l:current_offset = 0
      let l:i += 1
      continue
    elseif l:char ==# '$'
      let l:env_var = ''
      let l:i += 1

      while l:i < len(a:res.expand_arg)
        let l:char = a:res.expand_arg[l:i]
        if l:char ==# '/' ||
              \ l:allow_backslash && l:char ==# '\' ||
              \ match(l:char, '\f') != 0
          break
        endif

        let l:env_var .= l:char
        let l:i += 1
      endwhile

      if !empty(l:env_var)
        let l:expanded_env_var = expand('$' . l:env_var)
        " if result is the same, expansion failed
        if l:expanded_env_var !=# l:env_var
          let l:tail .= l:expanded_env_var
          let l:current_offset += len(l:expanded_env_var) - len(l:env_var) - 1

          if l:i == len(a:res.expand_arg)
            let l:no_fuzzy = 1
          endif
        endif
      endif

      continue
    elseif l:char ==# '*'
      if !get(a:res, 'has_wildcard', 0)
        let a:res.has_wildcard = 1
        let a:res.pos = l:file_arg_start
      endif
    endif

    let l:tail .= l:char
    let l:i += 1
  endwhile

  if !get(a:res, 'has_wildcard', 0)
    " expanded_pos is where pos should be after the $env_vars and filename
    " modifiers have been expanded
    let a:res.expanded_pos = a:res.pos
    for l:split in l:split_path
      let a:res.expanded_pos += len(l:split) + 1
    endfor

    " l:split_path includes the expanded $env_vars
    let a:res.pos = a:res.expanded_pos - l:offset
  endif

  " get first segment of path
  let l:prefix = !empty(l:split_path) ?
        \ l:split_path[0] :
        \ l:tail
  if !empty(l:split_path)
    let l:prefix = l:split_path[0]
    let a:res.relative_to_home_dir = l:prefix ==# '~'
  else
    let l:prefix = l:tail
  endif

  " expand first segment of path if needed
  if !empty(l:prefix)
    let l:expand_start = -1
    let l:expand_end = -1

    if l:prefix[0] ==# '~'
      let l:allow_backslash = has('win32') || has('win64')
      let l:expand_start = 0
      let l:expand_end = 0

      while l:expand_end + 1 < len(l:prefix)
        let l:char = l:prefix[l:expand_end + 1]

        if l:char ==# '\'
          if l:prefix[l:expand_end + 2] ==# ' '
            let l:expand_end += 2
            continue
          endif

          if l:allow_backslash
            break
          endif
        elseif l:char ==# '/'
          break
        endif

        let l:expand_end += 1
      endwhile
    elseif l:prefix[0] ==# '%' ||
          \ l:prefix[0] ==# '#'

      let l:expand_start = 0
      let l:expand_end = 0
    elseif l:prefix[0 : 6] ==# '<cfile>' ||
          \ l:prefix[0 : 6] ==# '<cword>' ||
          \ l:prefix[0 : 6] ==# '<cWORD>'
        let l:expand_start = 0
        let l:expand_end = 6
    elseif l:prefix[0 : 7] ==# '<client>'
        let l:expand_start = 0
        let l:expand_end = 7
    endif

    if l:expand_start != -1
      while l:expand_end + 2 < len(l:prefix) &&
            \ l:prefix[l:expand_end + 1] ==# ':' &&
            \ (l:prefix[l:expand_end + 2] ==# 'p' ||
            \ l:prefix[l:expand_end + 2] ==# 'h' ||
            \ l:prefix[l:expand_end + 2] ==# 't' ||
            \ l:prefix[l:expand_end + 2] ==# 'r' ||
            \ l:prefix[l:expand_end + 2] ==# 'e')
        let l:expand_end += 2
      endwhile

      let l:whole_path_expanded = l:expand_end == len(l:prefix) - 1
      let l:expanded = expand(l:prefix[l:expand_start : l:expand_end])

      if !empty(l:expanded)
        if l:whole_path_expanded && empty(l:split_path)
          let a:res.expand_arg = l:expanded . l:prefix[l:expand_end + 1]
          let a:res.use_arg = 1
          return a:res
        endif

        if !get(a:res, 'has_wildcard', 0)
          let a:res.expanded_pos += len(l:expanded) - l:expand_end + l:expand_start - 1
        endif

        if empty(l:split_path)
          let l:tail = l:expanded . l:prefix[l:expand_end+1 :]
        else
          let l:split_path[0] = l:expanded . l:prefix[l:expand_end+1 :]
        endif
      endif
    endif
  endif

  if empty(l:split_path)
    let l:path_prefix = ''
  else
    let l:path_prefix = join(l:split_path, l:slash)
    if l:path_prefix[-1 :] !=# l:slash
      let l:path_prefix .= l:slash
    endif
  endif

  if get(a:res, 'has_wildcard', 0)
    " don't use fuzzy match with wildcard
    let a:res.match_arg = ''
    let a:res.expand_arg = l:path_prefix . l:tail

    return a:res
  endif

  " don't trim leading / when drawing
  let a:res.path_prefix = l:path_prefix ==# '/' ? '' : l:path_prefix
  if get(a:res, 'relative_to_home_dir', 0)
    let a:res.path_prefix = fnamemodify(a:res.path_prefix, ':~')
  endif

  if !a:fuzzy || l:no_fuzzy
    let a:res.expand_arg = l:path_prefix . l:tail
    let a:res.fuzzy_char = ''
    let a:res.match_arg = l:tail
    return a:res
  endif

  let a:res.match_arg = l:tail
  let a:res.expand_arg = l:path_prefix
  let a:res.fuzzy_char = l:tail[0]
  return a:res
endfunction

function! wilder#cmdline#fuzzy_filter(ctx, candidates, query, ...) abort
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

  if a:0
    return filter(copy(a:candidates), {_, x -> match(a:1(x), l:regex) != -1})
  endif

  return filter(copy(a:candidates), {_, x -> match(x, l:regex) != -1})
endfunction

function! wilder#cmdline#python_fuzzy_filter(engine, ctx, candidates, query, ...) abort
  if empty(a:query)
    return a:candidates
  endif

  let l:regex = s:make_python_fuzzy_regex(a:query)

  if a:0
    let l:transformed = map(copy(a:candidates), {_, x -> a:1(x)})
  else
    let l:transformed = 0
  endif

  return {ctx -> _wilder_python_filter(ctx, l:regex, a:candidates, l:transformed, a:engine)}
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

function! wilder#cmdline#get_fuzzy_completion(ctx, res, getcompletion) abort
  if a:res.pos == len(a:res.cmdline) || a:res.expand ==# 'help'
    return a:getcompletion(a:ctx, a:res)
  endif

  let l:fuzzy_char = get(a:res, 'fuzzy_char', '')

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
        \ {ctx, lower_xs -> wilder#resolve(ctx, wilder#uniq(lower_xs + upper_xs))}))})
endfunction

function! wilder#cmdline#python_get_file_completion(ctx, res) abort
  if get(a:res, 'use_arg', 0)
    return [a:res.expand_arg]
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
    return getcompletion(l:expand_arg, 'buffer')
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

    return wilder#uniq(l:result)
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
  elseif a:res.expand ==# 'tags_listfiles'
    return getcompletion(l:expand_arg, 'tag_listfiles')
  elseif a:res.expand ==# 'var'
    return getcompletion(l:expand_arg, 'var')
  endif

  " fallback to cmdline getcompletion
  if has('nvim')
    return getcompletion(a:res.cmdline, 'cmdline')
  endif

  return []
endfunction

function! wilder#cmdline#has_file_args(expand) abort
  return a:expand ==# 'file' ||
        \ a:expand ==# 'file_in_path' ||
        \ a:expand ==# 'dir' ||
        \ a:expand ==# 'shellcmd' ||
        \ a:expand ==# 'user'
endfunction

function! wilder#cmdline#is_user_command(cmd) abort
  return !empty(a:cmd) && a:cmd[0] >=# 'A' && a:cmd[0] <=# 'Z'
endfunction

" returns [{handled}, {result}, {pos}]
function! wilder#cmdline#prepare_user_completion(ctx, res) abort
  if !wilder#cmdline#is_user_command(a:res.cmd)
    return [0, a:res]
  endif

  if !has('nvim')
    return [1, v:true]
  endif

  let l:user_commands = nvim_get_commands({})

  if !has_key(l:user_commands, a:res.cmd)
    return [1, v:false]
  endif

  let l:user_command = l:user_commands[a:res.cmd]

  if has_key(l:user_command, 'complete_arg') &&
        \ l:user_command.complete_arg isnot v:null
    let l:Completion_func = function(l:user_command.complete_arg)

    let l:result = l:Completion_func(a:res.cmdline[a:res.pos :], a:res.cmdline, len(a:res.cmdline))

    if get(l:user_command, 'complete', '') ==# 'custom'
      let l:result = split(l:result, '\n')
    endif

    return [1, l:result, a:res.pos]
  endif

  if has_key(l:user_command, 'complete') &&
        \ l:user_command['complete'] isnot v:null &&
        \ l:user_command['complete'] !=# 'custom' &&
        \ l:user_command['complete'] !=# 'customlist'
    let l:res = copy(a:res)
    let l:res['expand'] = l:user_command['complete']

    return [0, l:res]
  endif

  return [1, v:false]
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
        \ 'cmdline.command': a:res.cmd,
        \ 'cmdline.expand': a:res.expand,
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

  if has_key(a:res, 'expanded_pos')
    let l:data['cmdline.expanded_pos'] = a:res.expanded_pos
  endif

  return l:data
endfunction

function! s:getcompletion(ctx, res, fuzzy, use_python, has_file_args) abort
  let l:Completion_func = a:use_python && a:has_file_args
        \ ? funcref('wilder#cmdline#python_get_file_completion')
        \ : funcref('wilder#cmdline#getcompletion')

  if a:fuzzy
    let l:Getcompletion = {ctx, x -> wilder#cmdline#get_fuzzy_completion(
          \ ctx, x, l:Completion_func)}
  else
    let l:Getcompletion = l:Completion_func
  endif

  return wilder#wait(l:Getcompletion(a:ctx, a:res),
        \ {ctx, xs -> wilder#resolve(ctx, {
        \ 'value': xs,
        \ 'pos': a:has_file_args ?
        \   [{ctx, x, data -> s:get_file_args_pos(ctx, x, data, a:res.pos)}] :
        \   a:res.pos,
        \ 'data': s:convert_result_to_data(a:res),
        \ })})
endfunction

function! s:get_file_args_pos(ctx, x, data, pos) abort
  if a:x is v:null || !has_key(a:data, 'cmdline.expanded_pos')
    return a:pos
  endif

  return a:data['cmdline.expanded_pos']
endfunction

function! wilder#cmdline#getcompletion_pipeline(opts) abort
  let l:use_python = get(a:opts, 'use_python', has('nvim'))

  let l:fuzzy = get(a:opts, 'fuzzy', 0)
  if l:fuzzy
    if has_key(a:opts, 'fuzzy_filter')
      let l:Filter = a:opts['fuzzy_filter']
    elseif l:use_python
      let l:Filter = function('wilder#cmdline#python_fuzzy_filter', ['re'])
    else
      let l:Filter = function('wilder#cmdline#fuzzy_filter')
    endif

    let l:Fuzzy_filter = wilder#result({
          \ 'value': {ctx, xs, data -> l:Filter(
          \   ctx, xs, get(data, 'cmdline.match_arg', '')
          \ )}})

    let l:File_fuzzy_filter = wilder#result({
          \ 'value': {ctx, xs, data -> l:Filter(
          \   ctx, xs, get(data, 'cmdline.match_arg', ''),
          \   {x -> x[len(get(data, 'path_prefix', '')) :]}
          \ )}})
  endif

  let l:file_completion_subpipeline = [
        \ wilder#check({_, res -> wilder#cmdline#has_file_args(res.expand)}),
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

function! wilder#cmdline#hide_in_substitute(ctx, cmdline)
  let l:res = wilder#cmdline#parse(a:cmdline)
  if !wilder#cmdline#is_substitute_command(l:res.cmd)
    return a:cmdline
  endif

  let l:res = wilder#cmdline#substitute#parse({'cmdline': l:res.cmdline[l:res.pos :], 'pos': 0})

  if len(l:res) >= 2
    return v:true
  endif

  return a:cmdline
endfunction

let s:substitute_commands = {
      \ 'substitute': v:true,
      \ 'smagic': v:true,
      \ 'snomagic': v:true,
      \ 'global': v:true,
      \ 'vglobal': v:true,
      \ '&': v:true,
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

  let l:Sort = get(a:opts, 'sort', 0)
  if l:Sort isnot 0
    call add(l:getcompletion_pipeline, wilder#result({
          \ 'value': {ctx, xs, data ->
          \   l:Sort(ctx, xs, get(data, 'cmdline.match_arg', ''))}
          \ }))
  endif

  if get(a:opts, 'set_pcre2_pattern', 1)
    if get(a:opts, 'fuzzy', 0)
      call add(l:getcompletion_pipeline, wilder#result({
            \   'data': {ctx, data -> data is v:null ? {} : extend(data, {
            \     'pcre2.pattern': s:make_python_fuzzy_regex(get(data, 'cmdline.match_arg', ''))
            \   })},
            \ }))
    else
      call add(l:getcompletion_pipeline, wilder#result({
            \   'data': {ctx, data -> data is v:null ? {} : extend(data, {
            \     'pcre2.pattern': '(' .
            \         escape(get(data, 'cmdline.match_arg', ''), '\.^$*+?|(){}[]') . ')'
            \   })},
            \ }))
    endif
  endif

  call add(l:pipeline, wilder#branch(
        \ [
        \   {ctx, res -> res[0] ? res : v:false},
        \   {ctx, res -> wilder#result({
        \     'pos': res[2],
        \     'replace': ['wilder#cmdline#replace'],
        \   })(ctx, res[1])},
        \ ],
        \ l:getcompletion_pipeline,
        \ ))

  call add(l:pipeline, wilder#result({
        \   'data': {ctx, data -> data is v:null ? {} : extend(data, {
        \     'query': get(data, 'cmdline.match_arg', ''),
        \   })},
        \ }))

  return l:pipeline
endfunction
