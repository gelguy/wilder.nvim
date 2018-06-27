let s:pipeline = []
let s:func_index = 0
let s:funcs = {}

function! wildsearch#pipeline#ok(...)
  return v:null
endfunction

function! wildsearch#pipeline#fail(...)
  return v:false
endfunction

function! wildsearch#pipeline#reset_funcs()
  let s:func_index = 0
  let s:funcs = {}
endfunction

function! wildsearch#pipeline#register_func(f)
  let s:func_index += 1
  let s:funcs[s:func_index] = type(a:f) == v:t_string ? function(a:f) : a:f
  let g:a = s:funcs
  return s:func_index
endfunction

function! wildsearch#pipeline#register_funcs(fs)
  return map(copy(a:fs), {idx, f -> wildsearch#pipeline#register_func(f)})
endfunction

function! wildsearch#pipeline#unregister_func(key)
  unlet s:funcs[a:key]
endfunction

function! wildsearch#pipeline#call(key, ctx, x)
  if type(a:key) == v:t_string
    return function(a:key)(a:ctx, a:x)
  else
     return s:funcs[a:key](a:ctx, a:x)
  endif
endfunction

function! wildsearch#pipeline#set(pipeline)
  call wildsearch#pipeline#reset_funcs()

  let s:pipeline = wildsearch#pipeline#register_funcs(a:pipeline)
endfunction

function! wildsearch#pipeline#start(x)
  if len(s:pipeline) == 0
    call wildsearch#pipeline#set(wildsearch#pipeline#default())
  endif

  if !get(s:, 'wildsearch_init', 0)
    let s:wildsearch_init = 1
    call _wildsearch_init()
  endif

  let l:ctx = {
        \ 'fs': s:pipeline,
        \ 'input': a:x,
        \ 'on_finish': 'wildsearch#pipeline#on_finish',
        \ 'on_error': 'wildsearch#pipeline#on_error',
        \ 'start_time': reltime(),
        \}

  call wildsearch#pipeline#do(l:ctx, a:x)
endfunction

function! wildsearch#pipeline#do(ctx, x)
  let l:ctx = copy(a:ctx)

  if a:x is v:null
    " skip
    return
  elseif a:x is v:false || type(a:x) == v:t_dict && has_key(a:x, 'wildsearch_error')
    call wildsearch#pipeline#call(a:ctx.on_error, l:ctx, a:x)
    return
  endif

  if len(l:ctx.fs) == 0
    call wildsearch#pipeline#call(l:ctx.on_finish, l:ctx, a:x)
    return
  endif

  let l:f = l:ctx.fs[0]
  let l:ctx.fs = l:ctx.fs[1:]

  let l:res = wildsearch#pipeline#call(l:f, l:ctx, a:x)
  call wildsearch#pipeline#do(l:ctx, l:res)
endfunction

function! wildsearch#pipeline#on_finish(ctx, x)
  let &statusline = 'Result: ' . string(a:x)

  echom reltimestr(reltime(a:ctx.start_time))
endfunction

function! wildsearch#pipeline#on_error(ctx, x)
  if type(a:x) == v:t_dict && has_key(a:x, 'wildsearch_error')
    let &statusline = 'Error: ' . a:x.wildsearch_error
  endif
  echom reltimestr(reltime(a:ctx.start_time))
endfunction

function! wildsearch#pipeline#funcs()
  echom string(s:funcs)
endfunction

let g:opts = {'engine': 're', 'max_candidates': 500, 'sync': 0}
function! wildsearch#pipeline#default()
  return [wildsearch#python_search(g:opts), wildsearch#python_uniq(), {_, d -> join(d, ' ')}]

  " return [wildsearch#vim_search(g:opts), wildsearch#python_uniq(), {_, d -> join(d, ' ')}]

  " return [wildsearch#sleep(3), {_, x -> x + 2}, {_, x -> x * 2}, {_, x -> x + 2}]
  "
  " return [wildsearch#branch()]

  " return [
      " \ wildsearch#branch(
      " \  [{_, x -> x + 1}, {_, x -> x + 1}],
      " \ ),
      " \ {_, x -> x + 1},
      " \ {_, x -> x + 1},
      " \ ]

  " return [
      " \ wildsearch#branch(
      " \  [{_, __ -> v:false}],
      " \  [{_, __ -> v:false}],
      " \  [{_, x -> x + 1}, {_, x -> x * 2}, {_, x -> x + 1}]
      " \ ),
      " \ wildsearch#sleep(0),
      " \ {_, x -> x + 1},
      " \]

  " return [
      " \ wildsearch#branch(
      " \   [wildsearch#branch(
      " \     [wildsearch#sleep(1), {_, __ -> v:false}],
      " \     [wildsearch#sleep(1), {_, x -> x + 1}, {_, __ -> v:false}],
      " \   )],
      " \   [wildsearch#sleep(2), {_, x -> x + 1}],
      " \ ),
      " \ {_, x -> x * 2},
      " \ wildsearch#sleep(0),
      " \ {_, x -> x + 2},
      " \]
endfunction
