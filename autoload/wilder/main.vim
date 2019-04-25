scriptencoding utf-8

let s:enabled = 1
let s:init = 0
let s:active = 0
let s:hidden = 0
let s:run_id = 0
let s:result_run_id = -1
let s:draw_done = 0

let s:result = []
let s:selected = -1
let s:clear_selection = 1
let s:completion_stack = []

let s:opts = wilder#options#get()

function! wilder#main#in_mode() abort
  return mode(1) ==# 'c' && index(s:opts.modes, getcmdtype()) >= 0
endfunction

function! wilder#main#in_context() abort
  return wilder#main#in_mode() && !s:hidden && s:enabled
endfunction

function! wilder#main#enable_cmdline_enter() abort
  if !exists('#WilderCmdlineEnter')
    augroup WilderCmdlineEnter
      autocmd!
      autocmd CmdlineEnter * call wilder#main#start()
    augroup END
  endif
endfunction

function! wilder#main#disable_cmdline_enter() abort
  if exists('#WilderCmdlineEnter')
    augroup WilderCmdlineEnter
      autocmd!
    augroup END
    augroup! WilderCmdlineEnter
  endif
endfunction

function! wilder#main#start() abort
  " use timer_start so statusline does not flicker
  " when using mappings which performs a command
  call timer_start(0, {-> s:start()})

  return "\<Insert>\<Insert>"
endfunction

function! wilder#main#start_from_normal_mode() abort
  call timer_start(0, {-> s:start()})

  return ''
endfunction

function! s:start() abort
  if !wilder#main#in_mode() || !s:enabled
    call wilder#main#stop()
    return
  endif

  if has('nvim') && !s:init
    let s:init = 1
    call _wilder_init({'num_workers': s:opts.num_workers})
  endif

  if s:opts.use_cmdlinechanged
    if !exists('#WilderCmdlineChanged')
      augroup WilderCmdlineChanged
        autocmd!
        " call from a timer so statusline does not change during mappings
        autocmd CmdlineChanged * call timer_start(0, {_ -> s:do(1)})
      augroup END
    endif
  elseif !exists('s:timer')
      let s:timer = timer_start(s:opts.interval,
            \ {_ -> s:do(1)},
            \ {'repeat': -1})
  endif

  if !exists('#WilderCmdlineLeave')
    augroup WilderCmdlineLeave
      autocmd!
      autocmd CmdlineLeave * call wilder#main#stop()
    augroup END
  endif

  if !exists('#WilderVimResized')
    augroup WilderVimResized
      autocmd!
        autocmd VimResized * call timer_start(0, {_ -> s:draw_resized()})
    augroup END
  endif

  let s:active = 1
  let s:hidden = 0

  if !has_key(s:opts, 'renderer')
    let s:opts.renderer = wilder#statusline_renderer()
  endif

  if !has_key(s:opts, 'pipeline')
    if has('nvim')
      let s:opts.pipeline = [
            \ wilder#branch(
            \   wilder#cmdline_pipeline(),
            \   has('python3') ? wilder#python_search_pipeline() : wilder#vim_search_pipeline(),
            \ ),
            \ ]
    else
      let s:opts.pipeline = wilder#vim_search_pipeline()
    endif
  endif

  call s:pre_hook()

  call s:do(0)
endfunction

function! wilder#main#stop() abort
  if !s:active
    return
  endif

  if exists('#WilderCmdlineChanged')
    augroup WilderCmdlineChanged
      autocmd!
    augroup END
    augroup! WilderCmdlineChanged
  endif

  if exists('s:timer')
    call timer_stop(s:timer)
    unlet s:timer
  endif

  if exists('#WilderCmdlineLeave')
    augroup WilderCmdlineLeave
      autocmd!
    augroup END
    augroup! WilderCmdlineLeave
  endif

  if exists('#WilderVimResized')
    augroup WilderVimResized
      autocmd!
    augroup END
    augroup! WilderVimResized
  endif

  let s:active = 0
  let s:result = []
  let s:selected = -1
  let s:clear_selection = 0
  let s:completion_stack = []

  if exists('s:previous_cmdline')
    unlet s:previous_cmdline
  endif

  if exists('s:completion')
    unlet s:completion
  endif

  if exists('s:error')
    unlet s:error
  endif

  if exists('s:replaced_cmdline')
    unlet s:replaced_cmdline
  endif

  if !s:hidden
    call s:post_hook()
  endif

  let s:hidden = 0
endfunction

function! s:pre_hook() abort
  call wilder#render#init_hl()

  if has_key(s:opts.renderer, 'pre_hook')
    call s:opts.renderer.pre_hook({})
  endif

  if has_key(s:opts, 'pre_hook')
    call s:opts.pre_hook({})
  endif

  " create highlight before and after components since there might be
  " components which depend on existing highlights
  call wilder#render#init_hl()
endfunction

function! s:post_hook() abort
  if has_key(s:opts.renderer, 'post_hook')
    call s:opts.renderer.post_hook({})
  endif

  if has_key(s:opts, 'post_hook')
    call s:opts.post_hook({})
  endif
endfunction

function! s:do(check) abort
  if !s:active || !s:enabled
    return
  endif

  if a:check && !wilder#main#in_mode()
    call wilder#main#stop()
    return
  endif

  let l:input = s:getcmdline()

  let l:has_completion = exists('s:completion') && l:input ==# s:completion
  let l:is_new_input = !exists('s:previous_cmdline')
  let l:input_changed = exists('s:previous_cmdline') && s:previous_cmdline !=# l:input

  if !l:has_completion
    if exists('s:completion')
      unlet s:completion
    endif

    if exists('s:replaced_cmdline')
      unlet s:replaced_cmdline
    endif
  endif

  if !exists('s:previous_cmdline') || l:input_changed
    let s:previous_cmdline = l:input
  endif

  let s:draw_done = 0

  if !l:has_completion && (l:input_changed || l:is_new_input)
    call s:run_pipeline(l:input)

    if !s:draw_done
      call s:draw()
    endif
  endif

  let s:force = 0
endfunction

function! s:run_pipeline(input, ...) abort
  let s:run_id += 1

  let l:ctx = {
        \ 'input': a:input,
        \ 'run_id': s:run_id,
        \ }

  if a:0 > 0
    call extend(l:ctx, a:1)
  endif

  call wilder#pipeline#run(
        \ s:opts.pipeline,
        \ function('wilder#main#on_finish'),
        \ function('wilder#main#on_error'),
        \ l:ctx,
        \ a:input,
        \ )
endfunction

function! wilder#main#on_finish(ctx, x) abort
  if !s:active || !s:enabled
    return
  endif

  if a:ctx.run_id != s:run_id
    return
  endif

  let s:result_run_id = a:ctx.run_id

  let s:result = (a:x is v:false || a:x is v:true) ? [] : a:x
  let s:selected = -1
  let s:clear_selection = 1
  " keep previous completion

  if exists('s:error')
    unlet s:error
  endif

  if a:x is v:true
    if !s:hidden
      let s:hidden = 1

      call s:post_hook()
    endif

    return
  endif

  if s:hidden
    let s:hidden = 0

    call s:pre_hook()
  endif

  if len(s:completion_stack) > 0 && get(a:ctx, 'auto_select', 0)
    if exists('s:previous_cmdline')
      unlet s:previous_cmdline
    endif

    call wilder#main#next()
    return
  endif

  call s:draw()
endfunction

function! wilder#main#on_error(ctx, x) abort
  if !s:active || !s:enabled
    return
  endif

  if a:ctx.run_id != s:run_id
    return
  endif

  let s:result_run_id = a:ctx.run_id

  let s:result = []
  let s:selected = -1
  " keep previous completion

  let s:error = a:x

  call s:draw()
endfunction

function! wilder#main#draw() abort
  if !s:active || !s:enabled
    return 0
  endif

  call s:draw()
  return 1
endfunction

function! s:draw_resized() abort
  if !s:active || !s:enabled
    return
  endif

  call s:draw(0)
endfunction

function! s:draw(...) abort
  if s:hidden
    return
  endif

  try
      let l:direction = a:0 >= 1 ? a:1 : 0

      let l:ctx = {
            \ 'clear_previous': get(s:, 'clear_selection', 0),
            \ 'selected': s:selected,
            \ 'direction': l:direction,
            \ 'done': s:run_id == s:result_run_id,
            \ }
      let s:clear_selection = 0

      let l:has_error = exists('s:error')

      if l:has_error
        let l:ctx.error = s:error
      endif

      if l:has_error
        let l:xs = []
      else
        let l:xs = s:result
      endif

      call s:opts.renderer.render(l:ctx, l:xs)
  catch
    echohl ErrorMsg
    echomsg 'wilder: draw: ' . v:exception
    echohl Normal
  finally
    let s:draw_done = 1
  endtry
endfunction

function! wilder#main#next() abort
  return wilder#main#step(1)
endfunction

function! wilder#main#previous() abort
  return wilder#main#step(-1)
endfunction

function! wilder#main#step(num_steps) abort
  if !s:enabled
    " returning '' seems to prevent async completions from finishing
    " or prevent redrawing
    return "\<Insert>\<Insert>"
  endif

  if !s:active
    call s:start()
    return "\<Insert>\<Insert>"
  endif

  if s:hidden
    return "\<Insert>\<Insert>"
  endif

  if !exists('s:replaced_cmdline')
    let s:replaced_cmdline = s:getcmdline()
  endif

  if empty(s:completion_stack)
    let s:completion_stack = [s:replaced_cmdline]
  endif

  let l:previous_selected = s:selected

  let l:len = len(s:result)
  if a:num_steps == 0
    " pass
  elseif l:len == 0
    let s:selected = -1
  elseif l:len == 1
    let s:selected = 0
  else
    if s:selected < 0
      if a:num_steps > 0
        let l:selected = a:num_steps - 1
      else
        let l:selected = a:num_steps
      endif

      while l:selected < 0
        let l:selected += l:len
      endwhile
    else
      let l:selected = s:selected + a:num_steps

      while l:selected < -1
        let l:selected += l:len
      endwhile
    endif

    while l:selected > l:len
      let l:selected -= l:len
    endwhile

    let s:selected = l:selected == l:len ? -1 : l:selected
  endif

  if s:selected >= -1
    if s:selected >= 0
      let l:candidate = s:result[s:selected]

      if type(l:candidate) is v:t_dict
        let l:output = has_key(l:candidate, 'output')
              \ ? l:candidate.output({}, l:candidate.value)
              \ : l:candidate.value

        let l:Replace = get(l:candidate, 'replace', {_, x -> x})

        if type(l:Replace) is v:t_func
          let l:new_cmdline = l:Replace({'cmdline': s:replaced_cmdline}, l:output)
        else
          let l:new_cmdline = l:Replace
        endif
      else
        let l:new_cmdline = l:candidate
      endif
    else
      let l:new_cmdline = s:replaced_cmdline
    endif

    if l:previous_selected >= 0
      let s:completion_stack = s:completion_stack[1:]
    endif

    let s:completion = l:new_cmdline
    let s:completion_stack = [l:new_cmdline] + s:completion_stack

    call s:feedkeys_cmdline(l:new_cmdline)
  else
    if exists('s:completion')
      unlet s:completion
    endif

    if l:previous_selected >= 0
      let s:completion_stack = s:completion_stack[1:]
    endif
  endif

  call s:draw(a:num_steps)

  return "\<Insert>\<Insert>"
endfunction

function! s:getcmdline(...) abort
  if s:opts.use_cmdlinechanged || !s:opts.before_cursor
    return getcmdline()
  endif

  if a:0
    let l:cmdline = a:1
    let l:cmdpos = a:2
  else
    let l:cmdline = getcmdline()
    let l:cmdpos = getcmdpos()
  endif

  if l:cmdpos <= 1
    return ''
  else
    return l:cmdline[: l:cmdpos - 2]
  endif
endfunction

function! s:feedkeys_cmdline(cmdline) abort
  let l:chars = split(a:cmdline, '\zs')

  if s:opts.use_cmdlinechanged || !s:opts.before_cursor
    let l:keys = "\<C-E>\<C-U>"
  else
    let l:keys = "\<C-U>"
  endif

  for l:char in l:chars
    " control characters
    if l:char <# ' '
      let l:keys .= "\<C-Q>"
    endif

    let l:keys .= l:char
  endfor

  call feedkeys(l:keys, 'n')
endfunction

function! wilder#main#can_accept_completion() abort
  return wilder#main#in_context() &&
        \ exists('s:selected') && s:selected >= 0
endfunction

function! wilder#main#accept_completion() abort
  if exists('s:selected') && s:selected >= 0
    let l:cmdline = getcmdline()

    if exists('s:completion')
      unlet s:completion
    endif

    if exists('s:replaced_cmdline')
      unlet s:replaced_cmdline
    endif

    let s:previous_cmdline = l:cmdline
    let s:result = []
    let s:selected = -1
    let s:clear_selection = 1

    call s:run_pipeline(l:cmdline, {'auto_select': 1})
  endif

  return "\<Insert>\<Insert>"
endfunction

function! wilder#main#can_reject_completion() abort
  if len(s:completion_stack) > 1
    if s:getcmdline() !=# s:completion_stack[0]
      let s:completion_stack = []
    else
      while len(s:completion_stack) > 1 && s:completion_stack[0] ==# s:completion_stack[1]
        let s:completion_stack = s:completion_stack[1:]
      endwhile
    endif
  endif

  if len(s:completion_stack) <= 1
    let s:completion_stack = []
  endif

  return wilder#main#in_context() && !empty(s:completion_stack)
endfunction

function! wilder#main#reject_completion() abort
  if len(s:completion_stack) >= 2
    let s:completion_stack = s:completion_stack[1:]
    let l:cmdline = s:completion_stack[0]

    if exists('s:completion')
      unlet s:completion
    endif

    if exists('s:replaced_cmdline')
      unlet s:replaced_cmdline
    endif

    let s:previous_cmdline = l:cmdline
    let s:result = []
    let s:selected = -1
    let s:clear_selection = 1

    call s:feedkeys_cmdline(l:cmdline)
    call s:run_pipeline(l:cmdline)
  endif

  return "\<Insert>\<Insert>"
endfunction

function! wilder#main#enable() abort
  let s:enabled = 1

  return ''
endfunction

function! wilder#main#disable() abort
  let s:enabled = 0

  call wilder#main#stop()

  return ''
endfunction

function! wilder#main#toggle() abort
  if s:enabled
    return wilder#main#disable()
  endif

  return wilder#main#enable()
endfunction
