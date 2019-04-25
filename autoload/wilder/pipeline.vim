let s:handler_registry = {}
let s:id_index = 0

function! wilder#pipeline#on_finish(ctx, x) abort
  call s:handle(a:ctx, a:x, 'on_finish')
endfunction

function! wilder#pipeline#on_error(ctx, x) abort
  call s:handle(a:ctx, a:x, 'on_error')
endfunction

function! s:handle(ctx, x, key) abort
  let l:handler_id = get(a:ctx, 'handler_id', 0)

  if !has_key(s:handler_registry, l:handler_id)
    " avoid echoerr since this in a try-catch block
    " see try-echoerr
    echohl ErrorMsg
    echomsg 'wilder: ' . a:key . ' handler not found - id: ' . l:handler_id
    echohl Normal
    return
  endif

  let l:handler = s:handler_registry[l:handler_id]

  unlet s:handler_registry[l:handler_id]

  if a:key ==# 'on_error'
    call l:handler.on_error(a:ctx, a:x)
    return
  endif

  try
    call l:handler[a:key](a:ctx, a:x)
  catch
    call l:handler.on_error(a:ctx, 'pipeline: ' . v:exception)
  endtry
endfunction

function! wilder#pipeline#run(pipeline, on_finish, on_error, ctx, x) abort
  return s:run(a:pipeline, a:on_finish, a:on_error, a:ctx, a:x, 0)
endfunction

function! s:call(f, ctx) abort
  try
    call a:f(a:ctx)
  catch
    call wilder#pipeline#on_error(a:ctx, 'pipeline: ' . v:exception)
  endtry
endfunction

function! s:prepare_call(f, pipeline, on_finish, on_error, ctx, i)
  let l:handler = {
        \ 'on_finish': {ctx, x -> s:run(a:pipeline, a:on_finish, a:on_error, ctx, x, a:i)},
        \ 'on_error': {ctx, x -> a:on_error(ctx, x)},
        \ }

  let s:id_index += 1
  let s:handler_registry[s:id_index] = l:handler
  let a:ctx.handler_id = s:id_index

  call s:call(a:f, a:ctx)
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
