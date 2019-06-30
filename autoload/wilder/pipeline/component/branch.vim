function! wilder#pipeline#component#branch#make(args) abort
  if len(a:args) == 0
    return {_, x -> v:false}
  endif

  return {_, x -> {ctx -> s:start(a:args, ctx, x)}}
endfunction

function! s:start(pipelines, ctx, x) abort
  let l:state = {
        \ 'index': 0,
        \ 'pipelines': a:pipelines,
        \ 'original_ctx': a:ctx,
        \ 'original_x': a:x,
        \ }

  call wilder#pipeline#run(
        \ l:state.pipelines[0],
        \ {ctx, x -> s:on_finish(l:state, ctx, x)},
        \ {ctx, x -> s:on_error(l:state, ctx, x)},
        \ copy(a:ctx),
        \ copy(a:x),
        \ )
endfunction

function! s:on_finish(state, ctx, x) abort
  if a:x isnot v:false
    let a:ctx.handler_id = a:state.original_ctx.handler_id

    call wilder#resolve(a:ctx, a:x)
    return
  endif

  let a:state.index += 1

  if a:state.index >= len(a:state.pipelines)
    let a:ctx.handler_id = a:state.original_ctx.handler_id

    call wilder#resolve(a:ctx, v:false)
    return
  endif

  call wilder#pipeline#run(
        \ a:state.pipelines[a:state.index],
        \ {ctx, x -> s:on_finish(a:state, ctx, x)},
        \ {ctx, x -> s:on_error(a:state, ctx, x)},
        \ copy(a:state.original_ctx),
        \ copy(a:state.original_x),
        \ )
endfunction

function! s:on_error(state, ctx, x) abort
  let a:ctx.handler_id = a:state.original_ctx.handler_id

  call wilder#reject(a:ctx, a:x)
endfunction
