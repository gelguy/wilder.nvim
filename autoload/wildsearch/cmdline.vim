func wildsearch#cmdline#parse(cmdline) abort
  if exists('s:cache_cmdline') && a:cmdline ==# s:cache_cmdline
    return s:cache
  else
    let l:ctx = {'cmdline': a:cmdline, 'pos': 0, 'cmd': ''}
    call wildsearch#cmdline#main#do(l:ctx)

    let s:cache = l:ctx
    let s:cache_cmdline = a:cmdline
  endif

  return copy(l:ctx)
endfunc

function! wildsearch#cmdline#has_file_args(cmd)
  return wildsearch#cmdline#main#has_file_args(a:cmd)
endfunction

function! wildsearch#cmdline#is_user_command(cmd)
  return !empty(a:cmd) && a:cmd[0] >=# 'A' && a:cmd[0] <=# 'Z'
endfunction

function! wildsearch#cmdline#get_user_completion(cmdline)
  let l:ctx = wildsearch#cmdline#parse(a:cmdline)

  let l:user_commands = nvim_get_commands({})

  if !has_key(l:user_commands, l:ctx.cmd)
    return v:false
  endif

  let l:user_command = l:user_commands[l:ctx.cmd]

  if has_key(l:user_command, 'complete') &&
        \ l:user_command.complete !=# 'custom' && l:user_command.complete !=# 'customlist'
    let l:completions = cmdline(l:ctx.cmdline[l:ctx.pos :], l:user_command.complete)

    if l:user_command.complete ==# 'file' ||
          \ l:user_command.complete ==# 'file_in_path' ||
          \ l:user_command.complete ==# 'dir'
      return map(l:completions, {_, x -> escape(x, ' ')})
    endif

    return l:completions
  endif

  if !has_key(l:user_command, 'complete_arg') || l:user_command.complete_arg is v:null
    return v:false
  endif

  let l:Completion_func = function(l:user_command.complete_arg)

  " pos + 1 for the command prompt
  return l:Completion_func(l:ctx.cmdline[l:ctx.pos :], l:ctx.cmdline, l:ctx.pos + 1)
endfunction

func wildsearch#cmdline#replace(ctx, cmdline, x) abort
  let l:result = wildsearch#cmdline#parse(a:cmdline)

  if l:result.pos == 0
    return a:x
  endif

  if match(l:result.cmd, 'menu$') != -1
    return l:result.cmdline[: l:result.pos - 1] . a:x
  endif

  return l:result.cmdline[: l:result.pos - 1] . a:x
endfunction

let s:transform = {
      \ 'substitute': v:true,
      \ 'smagic': v:true,
      \ 'snomagic': v:true,
      \ 'global': v:true,
      \ 'vglobal': v:true,
      \ '&': v:true,
      \ }

function! wildsearch#cmdline#pipeline(opts) abort
  let l:Transform = get(a:opts, 'transform', s:transform)

  if type(l:Transform) == v:t_dict
    let l:dict = l:Transform
    let l:Transform = {_, res -> get(l:dict, res.cmd, res)}
  endif

  return [
      \ wildsearch#check({-> getcmdtype() ==# ':'}),
      \ {_, x -> wildsearch#cmdline#parse(x)},
      \ l:Transform,
      \ {_, res -> wildsearch#cmdline#is_user_command(res.cmd) ?
      \   wildsearch#cmdline#get_user_completion(res.cmdline) :
      \   wildsearch#cmdline#has_file_args(res.cmd) ?
      \   map(getcompletion(res.cmdline, 'cmdline'), {_, x -> escape(x, ' ')}) :
      \   getcompletion(res.cmdline, 'cmdline')
      \ },
      \ {_, xs -> map(xs, {_, x -> {'result': x, 'replace': 'wildsearch#cmdline#replace'}})},
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

function! wildsearch#cmdline#is_substitute_command(cmd)
  return has_key(s:substitute_commands, a:cmd)
endfunction

function! wildsearch#cmdline#substitute_pipeline(opts) abort
  let l:Pipeline = get(a:opts, 'pipeline', [
        \ wildsearch#python_substring(),
        \ wildsearch#python_search(),
        \ ])

  if type(l:Pipeline) == v:t_func
    let l:Pipeline = [l:Pipeline]
  endif

  let l:Pipeline = [{_, xs -> xs[1]}] + l:Pipeline

  return [
      \ wildsearch#check({-> getcmdtype() ==# ':'}),
      \ {_, x -> wildsearch#cmdline#parse(x)},
      \ wildsearch#check({_, res -> wildsearch#cmdline#is_substitute_command(res.cmd)}),
      \ {_, res -> wildsearch#cmdline#substitute#parse({'cmdline': res.cmdline[res.pos :], 'pos': 0})},
      \ wildsearch#check({_, x-> len(x) == 2}),
      \ wildsearch#map(
      \   [{_, xs -> xs[0]}],
      \   l:Pipeline,
      \ ),
      \ {_, xs -> map(xs[1], {_, x -> {'result': x,
      \    'draw': escape(x, '^$.*~[]\'),
      \    'output': xs[0] . x,
      \    'replace': 'wildsearch#cmdline#replace'
      \ }})},
      \ ]
endfunction
