function! wildsearch#pipeline#component#all#make(args)
  if len(a:args) == 0
    return {_, x -> []}
  endif

  return {ctx, x -> s:start({
        \ 'branches': a:args,
        \ 'fs_list': [],
        \ 'initialised': 0,
        \ }, ctx, x)}
endfunction

function s:start(args, ctx, x)
  if !a:args.initialised
      let a:args.fs_list = map(copy(a:args.branches), {_, fs -> wildsearch#pipeline#register_funcs(copy(fs))})

      let a:args.initialised = 1
  endif

  let l:args = {
        \ 'index': 0,
        \ 'fs_list': a:args.fs_list,
        \ 'original_ctx': a:ctx,
        \ 'original_x': a:x,
        \ 'result': [],
        \ }

  let l:args.on_error = wildsearch#pipeline#register_func({ctx, x -> s:on_error(l:args, ctx, x)})
  let l:args.on_finish = wildsearch#pipeline#register_func({ctx, x -> s:on_finish(l:args, ctx, x)})

  let l:ctx = copy(a:ctx)
  let l:ctx.fs = l:args.fs_list[0]
  let l:ctx.on_error = l:args.on_error
  let l:ctx.on_finish = l:args.on_finish

  call wildsearch#pipeline#do(l:ctx, a:x)
  return v:null
endfunction

function! s:on_error(args, ctx, x)
  call wildsearch#pipeline#do_error(a:args.original_ctx, a:x)
endfunction

function! s:on_finish(args, ctx, x)
  if a:x is v:false
    call wildsearch#pipeline#do(a:args.original_ctx, a:x)
    return
  endif

  call add(a:args.result, a:x)
  let a:args.index += 1

  if a:args.index >= len(a:args.fs_list)
    call wildsearch#pipeline#unregister_func(a:args.on_error)
    call wildsearch#pipeline#unregister_func(a:args.on_finish)

    call wildsearch#pipeline#do(a:args.original_ctx, a:args.result)
    return
  endif

  let l:ctx = copy(a:args.original_ctx)
  let l:ctx.fs = a:args.fs_list[a:args.index]
  let l:ctx.on_error = a:args.on_error
  let l:ctx.on_finish = a:args.on_finish

  call wildsearch#pipeline#do(l:ctx, a:args.original_x)
endfunction
