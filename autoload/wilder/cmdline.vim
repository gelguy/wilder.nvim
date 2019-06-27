function! wilder#cmdline#parse(cmdline) abort
  if !exists('s:cache_cmdline') || a:cmdline !=# s:cache_cmdline
    let l:ctx = {'cmdline': a:cmdline, 'pos': 0, 'cmd': '', 'expand': ''}
    call wilder#cmdline#main#do(l:ctx)

    let s:cache_cmdline_results = l:ctx
    let s:cache_cmdline = a:cmdline
  endif

  return copy(s:cache_cmdline_results)
endfunc

function! wilder#cmdline#prepare_getcompletion(ctx, res, fuzzy) abort
  let a:ctx.expand = a:res.expand
  let a:ctx.match_arg = a:res.cmdline[a:res.pos :]
  let a:res.expand_arg = a:res.cmdline[a:res.pos :]

  let a:res.expand_arg = has_key(a:res, 'subcommand_start') ?
        \ a:res.cmdline[a:res.subcommand_start :] :
        \ a:res.cmdline[a:res.pos :]

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
    let a:ctx.match_arg = a:res.expand_arg[2 :]
  elseif a:res.expand ==# 'mapping'
    " we want < to match special characters such as <Space>
    " a shortcut is to return everything and let the fuzzy matcher
    " handle the matching
    let l:prefix = ''
    let l:fuzzy_char = ''
    let a:ctx.match_arg = ''
  else
    let l:prefix = ''
    let l:fuzzy_char = a:res.expand_arg[0]
  endif

  let a:res.expand_arg = l:prefix
  let a:res.fuzzy_char = l:fuzzy_char
  return a:res
endfunction

function! wilder#cmdline#prepare_file_completion(ctx, res, fuzzy)
  let a:ctx.expand = a:res.expand
  let a:res.expand_arg = a:res.cmdline[a:res.pos :]

  let l:slash = has('win32') || has('win64') ?
        \ &shellslash ? '/' : '\' :
        \ '/'
  let l:allow_backslash = has('win32') || has('win64')

  " check prefix to see if expanding is needed
  let l:expand_start = -1
  let l:expand_end = -1
  let l:no_fuzzy = 0

  if a:res.expand_arg[0] ==# '~'
    let l:allow_backslash = has('win32') || has('win64')
    let l:expand_start = 0
    let l:expand_end = 0

    while l:expand_end + 1 < len(a:res.expand_arg)
      let l:char = a:res.expand_arg[l:expand_end + 1]

      if l:char ==# '\'
        if a:res.expand_arg[l:expand_end + 2] ==# ' '
          let l:expand_end += 2
          continue
        endif

        if l:allow_backslash
          break
        endif
      elseif l:char ==# '/'
        break
      endif
    endwhile
  elseif a:res.expand_arg[0] ==# '%' ||
        \ a:res.expand_arg[0] ==# '#'

    let l:expand_start = 0
    let l:expand_end = 0
  elseif a:res.expand_arg[0 : 6] ==# '<cfile>' ||
        \ a:res.expand_arg[0 : 6] ==# '<cword>' ||
        \ a:res.expand_arg[0 : 6] ==# '<cWORD>'
      let l:expand_start = 0
      let l:expand_end = 6
  elseif a:res.expand_arg[0 : 7] ==# '<client>'
      let l:expand_start = 0
      let l:expand_end = 7
  endif

  if l:expand_start != -1
    let l:no_fuzzy = 1

    while l:expand_end < len(a:res.expand_arg) &&
          \ a:res.expand_arg[l:expand_end + 1] ==# ':' &&
          \ (a:res.expand_arg[l:expand_end + 2] ==# 'p' ||
          \ a:res.expand_arg[l:expand_end + 2] ==# 'h' ||
          \ a:res.expand_arg[l:expand_end + 2] ==# 't' ||
          \ a:res.expand_arg[l:expand_end + 2] ==# 'r' ||
          \ a:res.expand_arg[l:expand_end + 2] ==# 'e')
      let l:expand_end += 2
    endwhile

    let l:prefix = a:res.expand_arg[l:expand_start : l:expand_end]
    let l:expanded_prefix = expand(l:prefix)

    let a:res.expand_arg = l:expanded_prefix . a:res.expand_arg[l:expand_end+1 :]
    let l:expand_end = len(l:expanded_prefix)
  endif

  " split path to check for wildcards and get tail
  let l:split_path = []

  if l:expand_end != -1
    let l:last_char = a:res.expand_arg[l:expand_end]

    if l:last_char ==# '/' ||
          \ l:allow_backslash && l:last_char ==# '\'
      if l:expand_end
        let l:split_path = [a:res.expand_arg[: l:expand_end - 1]]
      else
        let l:split_path = ['']
      endif

      let l:tail = ''
    else
      let l:tail = a:res.expand_arg[: l:expand_end]
    endif

    let l:i = l:expand_end + 1
    let l:char = a:res.expand_arg[l:i]
  else
    let l:tail = ''
    let l:i = 0
    let l:char = a:res.expand_arg[0]
  endif

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
        let l:i += 1
        continue
      endif
    elseif l:char ==# '/'
      call add(l:split_path, l:tail)
      let l:tail = ''
      let l:i += 1
      continue
    elseif l:char ==# '$'
      let l:env_var = ''
      let l:i += 1

      while l:i < len(a:res.expand_arg)
        let l:char = a:res.expand_arg[l:i]
        if l:char ==# '/' ||
              \ l:char ==# '\' ||
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
        endif
      endif

      continue
    elseif l:char ==# '*'
      let a:res.has_wildcard = 1
      break
    endif

    let l:tail .= l:char
    let l:i += 1
  endwhile

  if !empty(l:split_path)
    let l:no_fuzzy = 0
  endif

  if empty(l:split_path)
    let l:path_prefix = ''
  else
    let l:path_prefix = join(l:split_path, l:slash)
    if l:path_prefix[-1 :] !=# l:slash
      let l:path_prefix .= l:slash
    endif
  endif

  " don't trim leading /
  if l:path_prefix ==# '/'
    let a:ctx.path_prefix = ''
  else
    let a:ctx.path_prefix = l:path_prefix
  endif

  if get(a:res, 'has_wildcard', 0)
    " don't use fuzzy match with wildcard
    let a:ctx.match_arg = ''

    return a:res
  endif

  if !l:no_fuzzy
    let a:ctx.match_arg = l:tail
  else
    let a:ctx.match_arg = ''
  endif

  if l:no_fuzzy || !a:fuzzy
    return a:res
  endif

  let a:res.expand_arg = l:path_prefix
  let a:res.fuzzy_char = l:tail[0]
  return a:res
endfunction

function! wilder#cmdline#make_filter(f) abort
  return {ctx, xs -> s:filter(ctx, xs, a:f)}
endfunction

function! s:filter(ctx, xs, matcher) abort
  if a:ctx.expand ==# 'dir' ||
        \ a:ctx.expand ==# 'file' ||
        \ a:ctx.expand ==# 'file_in_path'
    return filter(a:xs, {_, x -> a:matcher(a:ctx, s:get_path_tail(s:get_value(x)), a:ctx.match_arg)})
  endif

  return filter(a:xs, {_, x -> a:matcher(a:ctx, s:get_value(x), a:ctx.match_arg)})
endfunction

function! s:get_value(x) abort
  if type(a:x) is v:t_dict
    return a:x.value
  endif

  return a:x
endfunction

function! wilder#cmdline#fuzzy_matcher(ctx, candidate, query) abort
  if empty(a:query)
    return 1
  endif

  if exists('s:cache_query') && a:query ==# s:cache_query
    let l:regex = s:cache_regex
  else
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

    let s:cache_query = a:query
    let s:cache_regex = l:regex
  endif

  return match(a:candidate, l:regex) != -1
endfunction

function! s:get_path_tail(path) abort
  let l:tail = fnamemodify(a:path, ':t')

  if empty(l:tail)
    return fnamemodify(a:path, ':h:t')
  endif

  return l:tail
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
        \ {ctx, upper_xs -> wilder#on_finish(ctx, wilder#wait(a:getcompletion(ctx, l:lower_res),
        \ {ctx, lower_xs -> wilder#on_finish(ctx, wilder#uniq(lower_xs + upper_xs))}))})
endfunction

function! wilder#cmdline#python_get_file_completion(ctx, res) abort
  let l:expand_arg = a:res.expand_arg

  if a:res.expand ==# 'dir' ||
        \ a:res.expand ==# 'file' ||
        \ a:res.expand ==# 'file_in_path' ||
        \ a:res.expand ==# 'shellcmd'

    if get(a:res, 'has_wildcard', 0)
      return {ctx -> _wilder_python_get_file_completion(ctx, getcwd(), l:expand_arg, a:res.expand, 1)}
    endif

    return {ctx -> _wilder_python_get_file_completion(ctx, getcwd(), l:expand_arg, a:res.expand, 0)}
  endif

  if a:res.expand ==# 'user'
    return {ctx -> _wilder_python_get_users(ctx, l:expand_arg, a:res.expand)}
  endif

  " fallback to normal getcompletion
  return wilder#cmdline#get_completion(a:ctx, a:res)
endfunction

function! wilder#cmdline#getcompletion(ctx, res) abort
  let l:expand_arg = a:res.expand_arg

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
  elseif a:res.expand ==# 'buffers'
    return getcompletion(l:expand_arg, 'buffer')
  elseif a:res.expand ==# 'checkhealth'
    return has('nvim') ? getcompletion(l:expand_arg, 'checkhealth') : []
  elseif a:res.expand ==# 'colors'
    return getcompletion(l:expand_arg, 'color')
  elseif a:res.expand ==# 'commands'
    return getcompletion(l:expand_arg, 'command')
  elseif a:res.expand ==# 'compiler'
    return getcompletion(l:expand_arg, 'compiler')
  elseif a:res.expand ==# 'cscope'
    return getcompletion(a:res.cmdline[a:res.subcommand_start :], 'cscope')
  elseif a:res.expand ==# 'dir'
    return getcompletion(l:expand_arg, 'dir', 1)
  elseif a:res.expand ==# 'events'
    return getcompletion(l:expand_arg, 'event')
  elseif a:res.expand ==# 'expression'
    return getcompletion(l:expand_arg, 'expression')
  elseif a:res.expand ==# 'env_vars'
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
        return filter(l:result, {_, x -> match(x, l:expand_arg) == 0})
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

    return l:result
  elseif a:res.expand ==# 'mapclear'
    return match('<buffer>', l:expand_arg) == 0 ? ['<buffer>'] : []
  elseif a:res.expand ==# 'messages'
    return getcompletion(l:expand_arg, 'messages')
  elseif a:res.expand ==# 'packadd'
    return getcompletion(l:expand_arg, 'packadd')
  elseif a:res.expand ==# 'profile'
    return filter(['continue', 'dump', 'file', 'func', 'pause',
          \ 'start'], {_, x -> match(x, l:expand_arg) == 0})
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

function! wilder#cmdline#has_file_args(cmd) abort
  return wilder#cmdline#main#has_file_args(a:cmd)
endfunction

function! wilder#cmdline#is_user_command(cmd) abort
  return !empty(a:cmd) && a:cmd[0] >=# 'A' && a:cmd[0] <=# 'Z'
endfunction

function! wilder#cmdline#get_user_completion(cmdline) abort
  let l:ctx = wilder#cmdline#parse(a:cmdline)

  let l:user_commands = nvim_get_commands({})

  if !has_key(l:user_commands, l:ctx.cmd)
    return v:false
  endif

  let l:user_command = l:user_commands[l:ctx.cmd]

  if has_key(l:user_command, 'complete_arg') && l:user_command.complete_arg isnot v:null
    let l:Completion_func = function(l:user_command.complete_arg)

    " pos + 1 for the command prompt
    let l:result = l:Completion_func(l:ctx.cmdline[l:ctx.pos :], l:ctx.cmdline, l:ctx.pos + 1)

    if get(l:user_command, 'complete', '') ==# 'custom'
      let l:result = split(l:result, '\n')
    endif

    return l:result
  endif

  if has_key(l:user_command, 'complete') && l:user_command.complete isnot v:null &&
        \ l:user_command.complete !=# 'custom' && l:user_command.complete !=# 'customlist'
    let l:completions = getcompletion(l:ctx.cmdline[l:ctx.pos :], l:user_command.complete, 1)

    if l:user_command.complete ==# 'file' ||
          \ l:user_command.complete ==# 'file_in_path' ||
          \ l:user_command.complete ==# 'dir'
      return map(l:completions, {_, x -> escape(x, ' ')})
    endif

    return l:completions
  endif

  return v:false
endfunction

function! wilder#cmdline#replace(ctx, x, prev) abort
  let l:result = wilder#cmdline#parse(a:ctx.cmdline)

  if l:result.pos == 0
    return a:x
  endif

  if l:result.cmd[-4 :] ==# 'menu'
    return l:result.cmdline[: l:result.pos - 1] . a:x
  endif

  if wilder#cmdline#is_substitute_command(l:result.cmd)
    let l:delimiter = l:result.cmdline[l:result.pos]

    return l:result.cmdline[: l:result.pos - 1] . l:delimiter . a:x
  endif

  return l:result.cmdline[: l:result.pos - 1] . a:x
endfunction

function! wilder#cmdline#draw_path(ctx, x, prev) abort
  if has_key(a:ctx, 'meta') &&
        \ type(a:ctx.meta) is v:t_dict &&
        \ has_key(a:ctx.meta, 'path_prefix')
    let l:path_prefix = a:ctx.meta.path_prefix
    let l:i = 0
    while l:i < len(l:path_prefix) &&
          \ l:path_prefix[l:i] ==# a:x[l:i]
      let l:i += 1
    endwhile

    return a:x[l:i :]
  endif

  return a:prev(a:ctx, a:x, a:x)
endfunction

function! wilder#cmdline#user_completion_pipeline() abort
  return [
      \ wilder#check({-> getcmdtype() ==# ':'}),
      \ {_, x -> wilder#cmdline#parse(x)},
      \ wilder#check({_, res -> wilder#cmdline#is_user_command(res.cmd)}),
      \ {_, res -> wilder#cmdline#get_user_completion(res.cmdline)},
      \ wilder#result({'replace': funcref('wilder#cmdline#replace')}),
      \ ]
endfunction

function! wilder#cmdline#getcompletion_pipeline(opts) abort
  let l:fuzzy = get(a:opts, 'fuzzy', 0)

  let l:Completion_func = funcref('wilder#cmdline#getcompletion')

  if l:fuzzy
    let l:Matcher = get(a:opts, 'fuzzy_matcher', funcref('wilder#cmdline#fuzzy_matcher'))
    let l:Getcompletion = {ctx, x -> wilder#cmdline#get_fuzzy_completion(
          \ ctx, x, l:Completion_func)}
  else
    let l:Getcompletion = l:Completion_func
  endif

  return [
      \ wilder#check({-> getcmdtype() ==# ':'}),
      \ {_, x -> wilder#cmdline#parse(x)},
      \ wilder#check({_, res -> has_key(res, 'expand') && !empty(res.expand)}),
      \ {ctx, res -> wilder#cmdline#prepare_getcompletion(ctx, res, l:fuzzy)},
      \ l:Getcompletion,
      \ ] +
      \ (l:fuzzy ? [wilder#cmdline#make_filter(l:Matcher)] : [])
      \ + [
      \ l:fuzzy ? wilder#cmdline#make_filter(l:Matcher) : {_, x -> x},
      \ wilder#result({'replace': funcref('wilder#cmdline#replace')}),
      \ ]
endfunction

function! wilder#cmdline#get_file_completion_pipeline(opts) abort
  let l:fuzzy = get(a:opts, 'fuzzy', 0)
  let l:use_python = get(a:opts, 'use_python', 0)

  let l:Completion_func = l:use_python ?
        \ funcref('wilder#cmdline#python_get_file_completion') :
        \ funcref('wilder#cmdline#get_file_completion')

  if l:fuzzy
    let l:Matcher = get(a:opts, 'fuzzy_matcher', funcref('wilder#cmdline#fuzzy_matcher'))
    let l:Getcompletion = {ctx, x -> wilder#cmdline#get_fuzzy_completion(
          \ ctx, x, l:Completion_func)}
  else
    let l:Getcompletion = l:Completion_func
  endif

  return [
      \ wilder#check({-> getcmdtype() ==# ':'}),
      \ {_, x -> wilder#cmdline#parse(x)},
      \ wilder#check({_, res -> wilder#cmdline#has_file_args(res.cmd)}),
      \ {ctx, res -> wilder#cmdline#prepare_file_completion(ctx, res, l:fuzzy)},
      \ l:Getcompletion,
      \ ] +
      \ (l:fuzzy ? [wilder#cmdline#make_filter(l:Matcher)] : [])
      \ + [
      \ wilder#result({
      \   'meta': {ctx, meta -> extend(meta, {'path_prefix': ctx.path_prefix})},
      \   'output': {_, x -> escape(x, ' ')},
      \   'draw': funcref('wilder#cmdline#draw_path'),
      \   'replace': funcref('wilder#cmdline#replace'),
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
  let l:pipeline = get(a:opts, 'pipeline', has('nvim') ?
        \ [
        \   wilder#python_substring(),
        \   wilder#python_search(),
        \   wilder#result_output_escape('^$,*~[]/\'),
        \ ] :
        \ [
        \   wilder#vim_substring(),
        \   wilder#vim_search(),
        \   wilder#result_output_escape('^$,*~[]/\'),
        \ ])

  if has_key(a:opts, 'hide_in_replace')
    let l:hide_in_replace = a:opts.hide_in_replace
  elseif has_key(a:opts, 'hide')
    " DEPRECATED: use hide_in_replace
    let l:hide_in_replace = a:opts.hide
  else
    let l:hide_in_replace = has('nvim') && !has('nvim-0.3.7')
  endif

  return [
      \ wilder#check({-> getcmdtype() ==# ':'}),
      \ {_, x -> wilder#cmdline#parse(x)},
      \ wilder#check({_, res -> wilder#cmdline#is_substitute_command(res.cmd)}),
      \ {_, res -> wilder#cmdline#substitute#parse({'cmdline': res.cmdline[res.pos :], 'pos': 0})},
      \ {_, res -> len(res) == 2 ? res[1] : (l:hide_in_replace ? v:true : v:false)},
      \ ] + l:pipeline + [
      \ wilder#result({'replace': funcref('wilder#cmdline#replace')}),
      \ ]
endfunction

function! wilder#cmdline#pipeline(opts) abort
  let l:fuzzy = get(a:opts, 'fuzzy', 0)
  let l:use_python_for_file_completion = get(a:opts, 'use_python_for_file_completion', 0)

  if has_key(a:opts, 'hide_in_substitute')
    let l:hide_in_substitute = a:opts.hide_in_substitute
  elseif has_key(a:opts, 'hide')
    " DEPRECATED: use hide_in_substitute
    let l:hide_in_substitute = a:opts.hide
  else
    let l:hide_in_substitute = has('nvim') && !has('nvim-0.3.7')
  endif

  let l:get_file_completion_opts = {
        \ 'fuzzy': l:fuzzy,
        \ 'use_python': l:use_python_for_file_completion,
        \ }
  let l:getcompletion_opts = {
        \ 'fuzzy': l:fuzzy,
        \ }

  if has_key(a:opts, 'fuzzy_matcher')
    let l:get_file_completion_opts.fuzzy_matcher = a:opts.fuzzy_matcher
    let l:getcompletion_opts.fuzzy_matcher = a:opts.fuzzy_matcher
  endif

  return [
        \ wilder#check({-> getcmdtype() ==# ':'}),
        \ l:hide_in_substitute ?
        \   {ctx, x -> wilder#cmdline#hide_in_substitute(ctx, x)} :
        \   {_, x -> x},
        \ wilder#branch(
        \   wilder#cmdline#user_completion_pipeline(),
        \   wilder#cmdline#get_file_completion_pipeline(l:get_file_completion_opts),
        \   wilder#cmdline#getcompletion_pipeline(l:getcompletion_opts),
        \ ),
        \ ]
endfunction
