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
    echoerr 'wilder: handler id not found: ' . l:handler_id
    return
  endif

  let l:handler = s:handler_registry[l:handler_id]

  unlet s:handler_registry[l:handler_id]

  call l:handler[a:key](a:ctx, a:x)
endfunction

function! wilder#pipeline#run(pipeline, on_finish, on_error, ctx, x)
  return s:run(a:pipeline, a:on_finish, a:on_error, a:ctx, a:x, 0)
endfunction

function! s:call(f, ctx, x) abort
  try
    call a:f(a:ctx, a:x)
  catch
    call wilder#pipeline#on_error(a:ctx, v:exception)
  endtry
endfunction

function! s:run(pipeline, on_finish, on_error, ctx, x, i)
  let l:x = a:x
  let l:i = a:i

  while l:i < len(a:pipeline)
    let l:F = a:pipeline[l:i]

    try
      let l:Result = l:F(a:ctx, l:x)
    catch
      call a:on_error(a:ctx, v:exception)
      return
    endtry

    if l:Result is v:false || l:Result is v:true
      call a:on_finish(a:ctx, l:Result)
      return
    endif

    if type(l:Result) is v:t_func
      let l:handler = {
            \ 'on_finish': {ctx, x -> s:run(a:pipeline, a:on_finish, a:on_error, ctx, x, i+1)},
            \ 'on_error': {ctx, err -> a:on_error(ctx, err)},
            \ }

      let s:id_index += 1
      let s:handler_registry[s:id_index] = l:handler

      let a:ctx['handler_id'] = s:id_index

      call timer_start(0, {-> s:call(l:Result, a:ctx, l:x)})
      return
    endif

    let l:x = l:Result
    let l:i += 1
  endwhile

  call a:on_finish(a:ctx, l:x)
endfunction
