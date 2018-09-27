let s:pipeline = []
let s:func_index = 0
let s:funcs = {}

function! wildsearch#pipeline#null(...) abort
  return v:null
endfunction

function! wildsearch#pipeline#true(...) abort
  return v:true
endfunction

function! wildsearch#pipeline#false(...) abort
  return v:false
endfunction

function! wildsearch#pipeline#reset_funcs() abort
  let s:func_index = 0
  let s:funcs = {}
endfunction

function! wildsearch#pipeline#register_func(f) abort
  let s:func_index += 1
  let s:funcs[s:func_index] = type(a:f) == v:t_func ? a:f : function(a:f)
  return s:func_index
endfunction

function! wildsearch#pipeline#register_funcs(fs) abort
  return map(copy(a:fs), {_, f -> wildsearch#pipeline#register_func(f)})
endfunction

function! wildsearch#pipeline#unregister_func(key) abort
  unlet s:funcs[a:key]
endfunction

function! wildsearch#pipeline#call(key, ctx, x) abort
  if type(a:key) == v:t_string
    return function(a:key)(a:ctx, a:x)
  else
     return s:funcs[a:key](a:ctx, a:x)
  endif
endfunction

function! wildsearch#pipeline#set_pipeline(pipeline) abort
  call wildsearch#pipeline#reset_funcs()

  let s:pipeline = wildsearch#pipeline#register_funcs(a:pipeline)
endfunction

function! wildsearch#pipeline#start(ctx, x) abort
  if len(s:pipeline) == 0
    call wildsearch#pipeline#set_pipeline(wildsearch#pipeline#default())
  endif

  let l:ctx = copy(a:ctx)
  let l:ctx.fs = s:pipeline
  let l:ctx.input = a:x
  let l:ctx.step = 0
  let l:ctx.start_time = reltime()

  call wildsearch#pipeline#do(l:ctx, a:x)
endfunction

function! wildsearch#pipeline#do(ctx, x) abort
  let l:ctx = copy(a:ctx)

  if a:x is v:null
    " skip
    return
  elseif a:x is v:false || a:x is v:true
    call wildsearch#pipeline#call(l:ctx.on_finish, l:ctx, a:x)
    return
  endif

  if len(l:ctx.fs) == 0
    call wildsearch#pipeline#call(l:ctx.on_finish, l:ctx, a:x)
    return
  endif

  let l:F = l:ctx.fs[0]
  let l:ctx.fs = l:ctx.fs[1:]
  let l:ctx.step += 1

  try
    let l:res = wildsearch#pipeline#call(l:F, l:ctx, a:x)
    call wildsearch#pipeline#do(l:ctx, l:res)
  catch
    call wildsearch#pipeline#do_error(l:ctx, v:exception)
  endtry
endfunction

function! wildsearch#pipeline#do_error(ctx, x) abort
  call wildsearch#pipeline#call(a:ctx.on_error, a:ctx, a:x)
endfunction

function! wildsearch#pipeline#_funcs() abort
  return copy(s:funcs)
endfunction

function! wildsearch#pipeline#default() abort
  if has('nvim')
    return [
          \ wildsearch#branch(
          \   wildsearch#getcompletion_pipeline(),
          \   wildsearch#python_search_pipeline(),
          \ ),
          \ ]
  else
    return wildsearch#vim_search_pipeline()
  endif
endfunction
