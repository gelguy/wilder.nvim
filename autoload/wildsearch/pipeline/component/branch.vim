function! wildsearch#pipeline#component#branch#make(args)
  if len(a:args) == 0
    return {_, x -> v:false}
  endif

  let l:args = {
        \ 'fs_list': a:args,
        \ 'initialised': 0,
        \ }

  return {ctx, x -> s:branch_start(l:args, ctx, x)}
endfunction

function! s:branch_start(args, ctx, x)
  if !a:args.initialised
      let a:args.fs_list = map(copy(a:args.fs_list), {_, fs -> wildsearch#pipeline#register_funcs(copy(fs))})

      let a:args.initialised = 1
  endif

  let l:state = {
        \ 'index': 0,
        \ 'fs_list': a:args.fs_list,
        \ 'original_ctx': a:ctx,
        \ 'original_x': a:x,
        \ }

  let l:state.on_error = wildsearch#pipeline#register_func({ctx, x -> s:branch_error(l:state, ctx, x)})
  let l:state.on_finish = wildsearch#pipeline#register_func({ctx, x -> s:branch_finish(l:state, ctx, x)})

  let l:ctx = copy(a:ctx)
  let l:ctx.fs = l:state.fs_list[0]
  let l:ctx.on_error = l:state.on_error
  let l:ctx.on_finish = l:state.on_finish

  call wildsearch#pipeline#do(l:ctx, a:x)
  return v:null
endfunction

function! s:branch_error(state, ctx, x)
  call wildsearch#pipeline#unregister_func(a:state.on_error)
  call wildsearch#pipeline#unregister_func(a:state.on_finish)

  call wildsearch#pipeline#do_error(a:state.original_ctx, a:x)
endfunction

function! s:branch_finish(state, ctx, x)
  if a:x isnot v:false
    call wildsearch#pipeline#unregister_func(a:state.on_error)
    call wildsearch#pipeline#unregister_func(a:state.on_finish)

    call wildsearch#pipeline#do(a:state.original_ctx, a:x)
    return
  endif

  let a:state.index += 1

  if a:state.index >= len(a:state.fs_list)
    call wildsearch#pipeline#unregister_func(a:state.on_error)
    call wildsearch#pipeline#unregister_func(a:state.on_finish)

    call wildsearch#pipeline#do(a:state.original_ctx, v:false)
    return
  endif

  let l:ctx = copy(a:state.original_ctx)
  let l:ctx.fs = a:state.fs_list[a:state.index]
  let l:ctx.on_error = a:state.on_error
  let l:ctx.on_finish = a:state.on_finish

  call wildsearch#pipeline#do(l:ctx, a:state.original_x)
endfunction
