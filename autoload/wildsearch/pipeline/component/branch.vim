function! wildsearch#pipeline#component#branch#make(args)
  if len(a:args) == 0
    return {_, x -> x}
  endif

  return {ctx, x -> s:branch_start({
        \ 'branches': a:args,
        \ 'fs': [],
        \ 'initialised': 0,
        \ }, ctx, x)}
endfunction

function! s:branch_start(args, ctx, x)
  if !a:args.initialised
      let a:args.fs = map(copy(a:args.branches), {_, fs -> wildsearch#pipeline#register_funcs(copy(fs))})

      let a:args.initialised = 1
  endif

  let l:args = {
        \ 'index': 0,
        \ 'fs': a:args.fs,
        \ 'original_ctx': a:ctx,
        \ 'original_x': a:x,
        \ }

  let l:args.on_error_key = wildsearch#pipeline#register_func({ctx, x -> s:branch_error(l:args, ctx, x)})
  let l:args.on_finish_key = wildsearch#pipeline#register_func({ctx, x -> s:branch_finish(l:args, ctx, x)})

  let l:ctx = copy(a:ctx)
  let l:ctx.fs = a:args.fs[0]
  let l:ctx.on_error = l:args.on_error_key
  let l:ctx.on_finish = l:args.on_finish_key

  call wildsearch#pipeline#do(l:ctx, a:x)
  return v:null
endfunction

function! s:branch_error(args, ctx, x)
  if type(a:x) == v:t_dict && has_key(a:x, 'wildsearch_error')
    call wildsearch#pipeline#do(a:args.original_ctx, a:x)
    return
  endif

  let a:args.index += 1

  if a:args.index >= len(a:args.fs)
    call wildsearch#pipeline#unregister_func(a:args.on_error_key)
    call wildsearch#pipeline#unregister_func(a:args.on_finish_key)

    call wildsearch#pipeline#do(a:args.original_ctx, v:false)
    return
  endif

  let l:ctx = copy(a:args.original_ctx)
  let l:ctx.fs = a:args.fs[a:args.index]
  let l:ctx.on_error = a:args.on_error_key
  let l:ctx.on_finish = a:args.on_finish_key

  call wildsearch#pipeline#do(l:ctx, a:args.original_x)
endfunction

function! s:branch_finish(args, ctx, x)
  call wildsearch#pipeline#unregister_func(a:args.on_error_key)
  call wildsearch#pipeline#unregister_func(a:args.on_finish_key)

  call wildsearch#pipeline#do(a:args.original_ctx, a:x)
endfunction
