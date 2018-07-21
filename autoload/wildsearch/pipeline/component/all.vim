function! wildsearch#pipeline#component#all#make(args) abort
  if len(a:args) == 0
    return {_, x -> []}
  endif

  let l:args = {
        \ 'fs_list': a:args,
        \ 'initialised': 0,
        \ }

  return {ctx, x -> s:start(l:args, ctx, x)}
endfunction

function! s:start(args, ctx, x)
  if !a:args.initialised
      let a:args.fs_list = map(copy(a:args.fs_list), {_, fs -> wildsearch#pipeline#register_funcs(copy(fs))})

      let a:args.initialised = 1
  endif

  let l:state = {
        \ 'index': 0,
        \ 'fs_list': a:args.fs_list,
        \ 'original_ctx': a:ctx,
        \ 'original_x': a:x,
        \ 'result': [],
        \ }

  let l:state.on_error = wildsearch#pipeline#register_func({ctx, x -> s:on_error(l:state, ctx, x)})
  let l:state.on_finish = wildsearch#pipeline#register_func({ctx, x -> s:on_finish(l:state, ctx, x)})

  let l:ctx = copy(a:ctx)
  let l:ctx.fs = l:state.fs_list[0]
  let l:ctx.on_error = l:state.on_error
  let l:ctx.on_finish = l:state.on_finish

  call wildsearch#pipeline#do(l:ctx, a:x)
  return v:null
endfunction

function! s:on_error(state, ctx, x) abort
  call wildsearch#pipeline#unregister_func(a:state.on_error)
  call wildsearch#pipeline#unregister_func(a:state.on_finish)

  call wildsearch#pipeline#do_error(a:state.original_ctx, a:x)
endfunction

function! s:on_finish(state, ctx, x) abort
  if a:x is v:false
    call wildsearch#pipeline#do(a:state.original_ctx, a:x)
    return
  endif

  call add(a:state.result, a:x)
  let a:state.index += 1

  if a:state.index >= len(a:state.fs_list)
    call wildsearch#pipeline#unregister_func(a:state.on_error)
    call wildsearch#pipeline#unregister_func(a:state.on_finish)

    call wildsearch#pipeline#do(a:state.original_ctx, a:state.result)
    return
  endif

  let l:ctx = copy(a:state.original_ctx)
  let l:ctx.fs = a:state.fs_list[a:state.index]
  let l:ctx.on_error = a:state.on_error
  let l:ctx.on_finish = a:state.on_finish

  call wildsearch#pipeline#do(l:ctx, a:state.original_x)
endfunction
