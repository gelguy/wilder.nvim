let s:func_index = 0
let s:funcs = {}

function! wildsearch#ok(...)
  return v:true
endfunction

function! wildsearch#fail(...)
  return v:false
endfunction

function! wildsearch#add(i)
  return {_, x -> a:i + x}
endfunction

function! wildsearch#times(i)
  return {_, x -> a:i * x}
endfunction

function! wildsearch#sleep(t)
  return {ctx, x -> wildsearch#ok(_wildsearch_sleep(ctx, a:t, x))}
endfunction

function! wildsearch#save_func(f)
  let s:func_index += 1
  let s:funcs[s:func_index] = type(a:f) == v:t_string ? function(a:f) : a:f
  let g:a = s:funcs
  return s:func_index
endfunction

function! wildsearch#branch(b, ...)
  let l:initialised = 0

  let l:args = {
        \ 'branches': [a:b] + a:000,
        \ 'fs': [],
        \ 'initialised': 0,
        \ }

  return {ctx, x -> s:branch_start(l:args, ctx, x)}
endfunction

function! s:branch_start(args, ctx, x)
  if !a:args.initialised
      let a:args.fs = map(copy(a:args.branches), {_, fs -> wildsearch#save_funcs(copy(fs))})

      let a:args.initialised = 1
  endif

  let l:args = {
        \ 'index': 0,
        \ 'fs': a:args.fs,
        \ 'original_ctx': a:ctx,
        \ 'original_x': a:x,
        \ }

  let l:args.on_error_key = wildsearch#save_func({ctx, x -> s:branch_error(l:args, ctx, x)})
  let l:args.on_finish_key = wildsearch#save_func({ctx, x -> s:branch_finish(l:args, ctx, x)})

  let l:ctx = {
        \ 'fs': a:args.fs[0],
        \ 'on_error': l:args.on_error_key,
        \ 'on_finish': l:args.on_finish_key,
        \ }

  call wildsearch#do(l:ctx, a:x)
  return v:true
endfunction

function! s:branch_error(args, ctx, x)
  let a:args.index += 1

  if a:args.index >= len(a:args.fs)
    unlet s:funcs[a:args.on_error_key]
    unlet s:funcs[a:args.on_finish_key]
    call wildsearch#do(a:args.original_ctx, v:false)
    return
  endif

  let l:ctx = {
        \ 'fs': a:args.fs[a:args.index],
        \ 'on_error': a:args.on_error_key,
        \ 'on_finish': a:args.on_finish_key,
        \ }

  call wildsearch#do(l:ctx, a:args.original_x)
endfunction

function! s:branch_finish(args, ctx, x)
  unlet s:funcs[a:args.on_error_key]
  unlet s:funcs[a:args.on_finish_key]
  call wildsearch#do(a:args.original_ctx, a:x)
endfunction

function! s:wildsearch_finish(ctx, x) dict
  let l:self.index += 1

  if l:self.index >= len(l:self.fs)
    call wildsearch#do(l:self.ctx, v:false)
    return
  endif

  let l:ctx = {
        \ 'fs': l:self.fs[l:self.index],
        \ 'on_error': l:self.on_error_key,
        \ 'on_finish': l:self.on_finish_key,
        \ }

  call wildsearch#do(l:ctx, l:self.x)
endfunction

function! wildsearch#set_pipeline(pipeline)
  call wildsearch#reset_funcs()

  let s:pipeline = wildsearch#save_funcs(a:pipeline)
endfunction

function! wildsearch#reset_funcs()
  let s:func_index = 0
  let s:funcs = {}
endfunction

function! wildsearch#save_funcs(fs)
  return map(copy(a:fs), {idx, f -> wildsearch#save_func(f)})
endfunction

function! wildsearch#start(x)
  let l:ctx = {
        \ 'fs': s:pipeline,
        \ 'on_finish': 'wildsearch#on_finish',
        \ 'on_error': 'wildsearch#on_error',
        \ 'start_time': reltime(),
        \}

  call wildsearch#do(l:ctx, a:x)
endfunction

function! wildsearch#do(ctx, x)
  if a:x is v:true
    " skip
    return
  elseif a:x is v:false
    call wildsearch#call(a:ctx.on_error, a:ctx, has_key(a:ctx, 'error_message') ? a:ctx.error_message : '')
    return
  endif

  if len(a:ctx.fs) == 0
    call wildsearch#call(a:ctx.on_finish, a:ctx, a:x)
    return
  endif

  let l:ctx = copy(a:ctx)
  let l:f = l:ctx.fs[0]
  let l:ctx.fs = l:ctx.fs[1:]

  let l:res = wildsearch#call(l:f, l:ctx, a:x)
  call wildsearch#do(l:ctx, l:res)
endfunction

function! wildsearch#call(key, ctx, x)
  if a:key ==# ''
    return
  elseif type(a:key) == v:t_string
    return function(a:key)(a:ctx, a:x)
  else
     return s:funcs[a:key](a:ctx, a:x)
  endif
endfunction

function! wildsearch#on_finish(ctx, x)
  let &statusline = 'Result: ' . string(a:x)

  echom reltimestr(reltime(a:ctx.start_time))
endfunction

function! wildsearch#on_error(ctx, message)
  if a:message !=# ''
    let &statusline = 'Error: ' . a:message
  endif
  echom reltimestr(reltime(a:ctx.start_time))
endfunction

function! wildsearch#funcs()
  echom string(s:funcs)
endfunction

" call wildsearch#set_pipeline([wildsearch#sleep(0), wildsearch#add(1), wildsearch#times(2), wildsearch#add(2)])

" call wildsearch#set_pipeline([
      " \ wildsearch#branch(
      " \  [wildsearch#add(1), wildsearch#add(1)],
      " \ ),
      " \ wildsearch#add(1),
      " \ wildsearch#add(1),
      " \ ])

call wildsearch#set_pipeline([
      \ wildsearch#branch(
      \  ['wildsearch#fail'],
      \  [{_, __ -> v:false}],
      \  [wildsearch#add(1), wildsearch#times(2), wildsearch#add(1)]
      \ ),
      \ wildsearch#sleep(0),
      \ wildsearch#add(1),
      \])

" call wildsearch#set_pipeline([
      " \ wildsearch#branch(
      " \   [wildsearch#branch(
      " \     [wildsearch#sleep(1), {_, __ -> v:false}],
      " \     [wildsearch#sleep(1), wildsearch#add(1), 'wildsearch#fail'],
      " \   )],
      " \   [wildsearch#sleep(2), wildsearch#add(1)],
      " \ ),
      " \ wildsearch#times(2),
      " \])
