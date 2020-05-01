let s:handler_registry = {}
let s:id_index = 0

function! wilder#pipeline#resolve(ctx, x) abort
  call s:handle(a:ctx, a:x, 'resolve')
endfunction

function! wilder#pipeline#reject(ctx, x) abort
  call s:handle(a:ctx, a:x, 'reject')
endfunction

function! s:handle(ctx, x, key) abort
  let l:handler_id = get(a:ctx, 'handler_id', 0)

  if !has_key(s:handler_registry, l:handler_id)
    let l:message = 'wilder: ' . a:key
    let l:message .= ' handler not found - id: ' . l:handler_id
    let l:message .= ': ' . string(a:x)

    " avoid echoerr since this in a try-catch block
    " see try-echoerr
    echohl ErrorMsg
    echomsg l:message
    echohl Normal
    return
  endif

  let l:handler = s:handler_registry[l:handler_id]

  unlet s:handler_registry[l:handler_id]

  if a:key ==# 'reject'
    call l:handler.on_error(a:ctx, a:x)
    return
  endif

  try
    call l:handler.on_finish(a:ctx, a:x)
  catch
    call l:handler.on_error(a:ctx, 'pipeline: ' . v:exception)
  endtry
endfunction

function! wilder#pipeline#run(pipeline, on_finish, on_error, ctx, x) abort
  let l:pipeline = type(a:pipeline) isnot v:t_list
        \ ? [a:pipeline]
        \ : a:pipeline

  return s:run(l:pipeline, a:on_finish, a:on_error, a:ctx, a:x, 0)
endfunction

function! s:call(f, ctx, handler_id) abort
  let a:ctx.handler_id = a:handler_id

  try
    call a:f(a:ctx)
  catch
    call wilder#reject(a:ctx, 'pipeline: ' . v:exception)
  endtry
endfunction

function! s:prepare_call(f, pipeline, on_finish, on_error, ctx, i)
  let l:handler = {
        \ 'on_finish': {ctx, x -> s:run(a:pipeline, a:on_finish, a:on_error, ctx, x, a:i)},
        \ 'on_error': {ctx, x -> a:on_error(ctx, x)},
        \ }

  let s:id_index += 1
  let l:handler_id = s:id_index
  let s:handler_registry[s:id_index] = l:handler

  call timer_start(0, {_ -> s:call(a:f, a:ctx, l:handler_id)})
endfunction

function! s:run(pipeline, on_finish, on_error, ctx, x, i) abort
  if a:x is v:false || a:x is v:true
    call a:on_finish(a:ctx, a:x)
    return
  endif

  if type(a:x) is v:t_func
    let l:ctx = copy(a:ctx)
    call s:prepare_call(a:x, a:pipeline, a:on_finish, a:on_error, l:ctx, a:i)
    return
  endif

  let l:x = a:x
  let l:i = a:i

  while l:i < len(a:pipeline)
    let l:F = a:pipeline[l:i]

    if type(l:F) isnot v:t_func
      call a:on_error(a:ctx, 'pipeline: expected function but got: ' . string(l:F))
      return
    endif

    try
      let l:Result = l:F(a:ctx, l:x)
    catch
      call a:on_error(a:ctx, 'pipeline: ' . v:exception)
      return
    endtry

    if l:Result is v:false || l:Result is v:true
      call a:on_finish(a:ctx, l:Result)
      return
    endif

    if type(l:Result) is v:t_func
      let l:ctx = copy(a:ctx)
      call s:prepare_call(l:Result, a:pipeline, a:on_finish, a:on_error, l:ctx, l:i+1)
      return
    endif

    let l:x = l:Result
    let l:i += 1
  endwhile

  call a:on_finish(a:ctx, l:x)
endfunction

function! wilder#pipeline#wait(f, on_finish, ...) abort
  let l:state = {
        \ 'f': a:f,
        \ 'on_finish': a:on_finish,
        \ }

  if a:0
    let l:state.on_error = a:1
  endif

  return {ctx -> s:wait_start(l:state, ctx)}
endfunction

function! s:wait_start(state, ctx)
  let a:state.wait_handler_id = a:ctx.handler_id

  let a:state.handler = {
        \ 'on_finish': {ctx, x -> s:wait_on_finish(a:state, ctx, x)},
        \ 'on_error': {ctx, x -> s:wait_on_error(a:state, ctx, x)},
        \ }

  call s:wait_call(a:state, a:ctx)
endfunction

function! s:wait_call(state, ctx)
  try
    if type(a:state.f) is v:t_func
      let l:ctx = copy(a:ctx)

      let s:id_index += 1
      let l:id_index = s:id_index
      let s:handler_registry[s:id_index] = a:state.handler

      call timer_start(0, {_ -> s:call(a:state.f, l:ctx, l:id_index)})
    else
      let a:ctx.handler_id = a:state.wait_handler_id
      call a:state.on_finish(a:ctx, a:state.f)
    endif
  catch
    let a:ctx.handler_id = a:state.wait_handler_id
    call s:wait_on_error(a:state, a:ctx, v:exception)
  endtry
endfunction

function! s:wait_on_finish(state, ctx, x)
  if type(a:x) is v:t_func
    let a:state.f = a:x
    call s:wait_call(a:state, a:ctx)
    return
  endif

  let l:ctx = copy(a:ctx)
  let l:ctx.handler_id = a:state.wait_handler_id

  try
    call a:state.on_finish(l:ctx, a:x)
  catch
    if has_key(a:state, 'on_error')
      call a:state.on_error(l:ctx, v:exception)
    else
      call wilder#reject(l:ctx, v:exception)
    endif
  endtry
endfunction

function! s:wait_on_error(state, ctx, x)
  let l:ctx = copy(a:ctx)
  let l:ctx.handler_id = a:state.wait_handler_id

  if has_key(a:state, 'on_error')
    call a:state.on_error(l:ctx, a:x)
  else
    call wilder#reject(l:ctx, a:x)
  endif
endfunction
