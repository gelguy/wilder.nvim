function! wild#pipeline#component#map#make(args) abort
  if len(a:args) == 0
    return {_, x -> []}
  endif

  let l:args = {
        \ 'fs_list': a:args,
        \ 'initialised': 0,
        \ }

  return {ctx, x -> s:start(l:args, ctx, x)}
endfunction

function! s:start(args, ctx, x) abort
  if !a:args.initialised
      let a:args.fs_list = map(copy(a:args.fs_list), {_, fs -> wild#pipeline#register_funcs(copy(fs))})

      let a:args.initialised = 1
  endif

  let l:len = len(a:args.fs_list)

  let l:state = {
        \ 'original_ctx': a:ctx,
        \ 'results': repeat([0], l:len),
        \ 'finished': 0,
        \ 'has_error': 0,
        \ 'on_error': wild#pipeline#register_func({_, x -> s:on_error(l:state, x)}),
        \ 'on_finish': repeat([0], l:len),
        \ }

  let l:i = 0
  while l:i < l:len
    let l:ctx = copy(a:ctx)
    let l:ctx.fs = a:args.fs_list[l:i]

    let l:on_finish = {i -> wild#pipeline#register_func({_, x -> s:on_finish(l:state, i, x)})}(l:i)
    let l:ctx.on_finish = l:on_finish
    let l:state.on_finish[l:i] = l:on_finish

    call wild#pipeline#do(l:ctx, a:x)

    let l:i += 1
  endwhile

  return v:null
endfunction

function! s:on_error(state, x) abort
  let a:state.finished += 1

  if a:state.finished >= len(a:state.results)
    call wild#pipeline#unregister_func(a:state.on_error)
    for l:f in a:state.on_finish
      call wild#pipeline#unregister_func(l:f)
    endfor
  endif

  if !a:state.has_error
    call wild#pipeline#do_error(a:state.original_ctx, a:x)

    let a:state.has_error = 1
  endif
endfunction

function! s:on_finish(state, index, x) abort
  let a:state.results[a:index] = a:x

  let a:state.finished += 1

  if a:state.finished >= len(a:state.results)
    call wild#pipeline#unregister_func(a:state.on_error)
    for l:f in a:state.on_finish

      call wild#pipeline#unregister_func(l:f)
    endfor

    call wild#pipeline#do(a:state.original_ctx, a:state.results)
  endif
endfunction
