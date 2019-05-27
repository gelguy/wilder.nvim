function! wilder#cmdline#parse(cmdline) abort
  if exists('s:cache_cmdline') && a:cmdline ==# s:cache_cmdline
    return s:cache_cmdline_results
  else
    let l:ctx = {'cmdline': a:cmdline, 'pos': 0, 'cmd': '', 'expand': ''}
    call wilder#cmdline#main#do(l:ctx)

    let s:cache_cmdline_results = l:ctx
    let s:cache_cmdline = a:cmdline
  endif

  return copy(l:ctx)
endfunc

function! wilder#cmdline#getcompletion(ctx, res, fuzzy) abort
  let a:ctx.arg = a:res.cmdline[a:res.pos :]
  let a:ctx.expand = a:res.expand

  " if argument is empty, use normal completions
  " up to 300 help tags returned, so fuzzy matching does not work
  if !a:fuzzy || a:res.pos == len(a:res.cmdline) || a:res.expand ==# 'help'
    return s:getcompletion(a:res)
  endif

  let l:cmdline = a:res.cmdline

  let l:offset = 0
  if (a:res.expand ==# 'expression' || a:res.expand ==# 'user_vars') &&
        \ a:ctx.arg[1] ==# ':' &&
        \ (a:ctx.arg[0] ==# 'g' || a:ctx.arg[0] ==# 's')
    let l:offset = 2
  elseif a:res.expand ==# 'directories' ||
        \ a:res.expand ==# 'files' ||
        \ a:res.expand ==# 'files_in_path'
    let l:expand = expand(a:res.cmdline[a:res.pos :], 0, 1)

    if len(l:expand) > 1
      let a:ctx.arg = '*'
      return l:expand
    else
      let l:path = simplify(l:expand[0])
      let a:res.cmdline = a:res.cmdline[: a:res.pos - 1] . l:path
      let l:tail = fnamemodify(l:path, ':t')

      if l:tail ==# '.'
        let a:ctx.arg = ''
      else
        let a:ctx.arg = l:tail
        let l:offset = len(l:path) - len(l:tail)
      endif
    endif
  endif

  let l:char = a:res.cmdline[a:res.pos + l:offset]

  let l:xs = []

  if l:char !=# toupper(l:char)
    let a:res.cmdline = a:res.cmdline[: a:res.pos + l:offset - 1] . toupper(l:char)
    let l:xs += s:getcompletion(a:res)
  endif

  let a:res.cmdline = l:cmdline[: a:res.pos + l:offset]
  let l:xs += s:getcompletion(a:res)

  let a:res.cmdline = l:cmdline

  return wilder#pipeline#component#vim_uniq#do({}, l:xs)
endfunc

function! wilder#cmdline#make_filter(f)
  return {ctx, xs -> s:filter(ctx, xs, a:f)}
endfunction

function! s:filter(ctx, xs, matcher)
  let l:arg = a:ctx.arg

  if a:ctx.expand ==# 'directories' ||
        \ a:ctx.expand ==# 'files' ||
        \ a:ctx.expand ==# 'files_in_path'
    if l:arg ==# '*'
      return a:xs
    endif

    return filter(a:xs, {_, x -> a:matcher(a:ctx, s:get_path_tail(x), l:arg)})
  endif

  return filter(a:xs, {_, x -> a:matcher(a:ctx, x, l:arg)})
endfunction

function! wilder#cmdline#fuzzy_matcher(ctx, x, arg)
  if empty(a:arg)
    return 1
  endif

  if exists('s:cache_arg') && a:arg ==# s:cache_arg
    let l:regex = s:cache_regex
  else
    " make fuzzy regex
    let l:split_arg = split(a:arg, '\zs')
    let l:i = 0
    let l:regex = '\V'
    while l:i < len(l:split_arg)
      if l:i > 0
        let l:regex .= '\.\{-}'
      endif

      let l:c = l:split_arg[l:i]

      if l:c ==# '\'
        let l:regex .= '\\'
      elseif l:c ==# toupper(l:c)
        let l:regex .= l:c
      else
        let l:regex .= '\%(' . l:c . '\|' . toupper(l:c) . '\)'
      endif

      let l:i += 1
    endwhile

    let s:cache_arg = a:arg
    let s:cache_regex = l:regex
  endif

  return match(a:x, l:regex) != -1
endfunction

function! s:get_path_tail(path) abort
  let l:tail = fnamemodify(a:path, ':t')

  if empty(l:tail)
    return fnamemodify(a:path, ':h:t')
  endif

  return l:tail
endfunction

function! s:getcompletion(res) abort
  let l:arg = a:res.cmdline[a:res.pos :]

  if a:res.expand ==# 'nothing' || a:res.expand ==# 'unsuccessful'
    return []
  elseif a:res.expand ==# 'augroup'
    return getcompletion(l:arg, 'augroup')
  elseif a:res.expand ==# 'arglist'
    return getcompletion(l:arg, 'arglist')
  elseif a:res.expand ==# 'behave'
    return getcompletion(l:arg, 'behave')
  elseif a:res.expand ==# 'buffers'
    return getcompletion(l:arg, 'buffer')
  elseif a:res.expand ==# 'checkhealth'
    return has('nvim') ? getcompletion(l:arg, 'checkhealth') : []
  elseif a:res.expand ==# 'colors'
    return getcompletion(l:arg, 'color')
  elseif a:res.expand ==# 'commands'
    return getcompletion(l:arg, 'command')
  elseif a:res.expand ==# 'compiler'
    return getcompletion(l:arg, 'compiler')
  elseif a:res.expand ==# 'cscope'
    return getcompletion(a:res.cmdline[a:res.subcommand_start :], 'cscope')
  elseif a:res.expand ==# 'directories'
    return getcompletion(l:arg, 'dir')
  elseif a:res.expand ==# 'events'
    return getcompletion(l:arg, 'event')
  elseif a:res.expand ==# 'expression'
    return getcompletion(l:arg, 'expression')
  elseif a:res.expand ==# 'env_vars'
    return getcompletion(l:arg, 'environment')
  elseif a:res.expand ==# 'files'
    return getcompletion(l:arg, 'file')
  elseif a:res.expand ==# 'files_in_path'
    return getcompletion(l:arg, 'files_in_path')
  elseif a:res.expand ==# 'functions'
    return getcompletion(l:arg, 'function')
  elseif a:res.expand ==# 'help'
    return getcompletion(l:arg, 'help')
  elseif a:res.expand ==# 'highlight'
    return getcompletion(l:arg, 'highlight')
  elseif a:res.expand ==# 'history'
    return getcompletion(l:arg, 'history')
  elseif a:res.expand ==# 'language'
    return getcompletion(l:arg, 'locale') +
          \ filter(['ctype', 'messages', 'time'], {_, x -> match(x, l:arg) == 0})
  elseif a:res.expand ==# 'locales'
    return getcompletion(l:arg, 'locale')
  elseif a:res.expand ==# 'mapping'
    " TODO: handle mapping
  elseif a:res.expand ==# 'messages'
    return getcompletion(l:arg, 'messages')
  elseif a:res.expand ==# 'packadd'
    return getcompletion(l:arg, 'packadd')
  elseif a:res.expand ==# 'profile'
    return filter(['continue', 'dump', 'file', 'func', 'pause',
          \ 'start'], {_, x -> match(x, l:arg) == 0})
  elseif a:res.expand ==# 'ownsyntax'
    return getcompletion(l:arg, 'syntax')
  elseif a:res.expand ==# 'shellcmd'
    return getcompletion(l:arg, 'shellcmd')
  elseif a:res.expand ==# 'sign'
    return getcompletion(a:res.cmdline[a:res.subcommand_start :], 'sign')
  elseif a:res.expand ==# 'syntax'
    return getcompletion(l:arg, 'syntax')
  elseif a:res.expand ==# 'syntime'
    return getcompletion(l:arg, 'syntime')
  elseif a:res.expand ==# 'syntime'
    return getcompletion(l:arg, 'syntime')
  elseif a:res.expand ==# 'user_func'
    let l:functions = getcompletion(l:arg, 'function')
    let l:functions = filter(l:functions, {_, x -> !(x[0] >= 'a' && x[0] <= 'z')})
    return map(l:functions, {_, x -> x[-1 :] ==# ')' ? x[: -3] : x[: -2]})
  elseif a:res.expand ==# 'user_addr_type'
    return filter(['arguments', 'buffers', 'lines', 'loaded_buffers',
          \ 'quickfix', 'tabs', 'windows'], {_, x -> match(x, l:arg) == 0})
  elseif a:res.expand ==# 'user_cmd_flags'
    return filter(['addr', 'bar', 'buffer', 'complete', 'count',
          \ 'nargs', 'range', 'register'], {_, x -> match(x, l:arg) == 0})
  elseif a:res.expand ==# 'user_complete'
    return filter(['arglist', 'augroup', 'behave', 'buffer', 'checkhealth',
          \ 'color', 'command', 'compiler', 'cscope', 'custom',
          \ 'customlist', 'dir', 'environment', 'event', 'expression',
          \ 'file', 'file_in_path', 'filetype', 'function', 'help',
          \ 'highlight', 'history', 'locale', 'mapclear', 'mapping',
          \ 'menu', 'messages', 'option', 'packadd', 'shellcmd',
          \ 'sign', 'syntax', 'syntime', 'tag', 'tag_listfiles',
          \ 'user', 'var'], {_, x -> match(x, l:arg) == 0})
  elseif a:res.expand ==# 'user_nargs'
    if empty(l:arg)
      return ['*', '+', '0', '1', '?']
    endif

    if l:arg ==# '*' || l:arg ==# '+' || l:arg ==# '0' ||
          \ l:arg ==# '1' || l:arg ==# '?'
      return [l:arg]
    endif

    return []
  elseif a:res.expand ==# 'user_commands'
    return filter(getcompletion(l:arg, 'command'), {_, x -> !(x[0] >= 'a' && x[0] <= 'z')})
  elseif a:res.expand ==# 'tags_listfiles'
    return getcompletion(l:arg, 'tag_listfiles')
  elseif a:res.expand ==# 'user_vars'
    return getcompletion(l:arg, 'var')
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

  if match(l:result.cmd, 'menu$') != -1
    return l:result.cmdline[: l:result.pos - 1] . a:x
  endif

  if wilder#cmdline#is_substitute_command(l:result.cmd)
    let l:delimiter = l:result.cmdline[l:result.pos]

    return l:result.cmdline[: l:result.pos - 1] . l:delimiter . a:x
  endif

  return l:result.cmdline[: l:result.pos - 1] . a:x
endfunction

function! wilder#cmdline#pipeline(opts) abort
  let l:hide = get(a:opts, 'hide', 1)
  let l:max_candidates = get(a:opts, 'max_candidates', 300)
  let l:fuzzy = get(a:opts, 'fuzzy', 0)

  if !has_key(a:opts, 'pipeline')
    let l:pipeline = l:fuzzy ? [wilder#cmdline_filter(wilder#fuzzy_matcher())] : []
  else
    let l:pipeline = a:opts.pipeline
  endif

  return [
      \ wilder#check({-> getcmdtype() ==# ':'}),
      \ {_, x -> wilder#cmdline#parse(x)},
      \ wilder#branch(
      \   [
      \     wilder#check({_, res -> wilder#cmdline#is_substitute_command(res.cmd)}),
      \     {-> l:hide ? v:true : v:false},
      \   ],
      \   [
      \     wilder#check({_, res -> wilder#cmdline#is_user_command(res.cmd)}),
      \     {_, res -> wilder#cmdline#get_user_completion(res.cmdline)},
      \   ],
      \   [
      \     wilder#check({_, res -> wilder#cmdline#has_file_args(res.cmd)}),
      \     {ctx, res -> map(wilder#cmdline#getcompletion(ctx, res, l:fuzzy), {_, x -> escape(x, ' ')})},
      \   ] + l:pipeline,
      \   [
      \     {ctx, res -> wilder#cmdline#getcompletion(ctx, res, l:fuzzy)},
      \   ] + l:pipeline,
      \ ),
      \ {_, xs -> l:max_candidates > 0 ? xs[: l:max_candidates - 1] : xs},
      \ wilder#result({'replace': funcref('wilder#cmdline#replace')}),
      \ ]
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

  let l:hide = get(a:opts, 'hide', 1)

  return [
      \ wilder#check({-> getcmdtype() ==# ':'}),
      \ {_, x -> wilder#cmdline#parse(x)},
      \ wilder#check({_, res -> wilder#cmdline#is_substitute_command(res.cmd)}),
      \ {_, res -> wilder#cmdline#substitute#parse({'cmdline': res.cmdline[res.pos :], 'pos': 0})},
      \ wilder#check({_, res -> len(res) > 0}),
      \ {_, res -> len(res) == 2 ? res[1] : (l:hide ? v:true : v:false)},
      \ ] + l:pipeline + [
      \ wilder#result({'replace': funcref('wilder#cmdline#replace')}),
      \ ]
endfunction
