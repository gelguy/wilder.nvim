scriptencoding utf-8

let s:init = 0
let s:auto = 0
let s:active = 0
let s:run_id = 0
let s:result_run_id = -1
let s:draw_done = 0
let s:modes = ['/', '?']

let s:candidates = []
let s:selected = -1
let s:completion = ''
let s:page = [-1, -1]

let s:opts = {
      \ 'interval': 100,
      \ 'pre_hook': 'wildsearch#main#save_statusline',
      \ 'post_hook': 'wildsearch#main#restore_statusline',
      \ 'num_workers': 2,
      \ }

function! wildsearch#main#set_option(key, value)
  let s:opts[a:key] = a:value
endfunction

function! wildsearch#main#set_options(opts)
  let s:opts = extend(s:opts, a:opts)
endfunction

function! wildsearch#main#get_option(key)
  return s:opts[a:key]
endfunction

function! wildsearch#main#in_context()
  return index(s:modes, getcmdtype()) >= 0
endfunction

function! wildsearch#main#enable_auto(...)
  if !exists('#Wildsearch')
    augroup Wildsearch
      autocmd!
      autocmd CmdlineEnter * call wildsearch#main#start_auto()
      autocmd CmdlineLeave * call wildsearch#main#stop_auto()
    augroup END
  endif
endfunction

function! wildsearch#main#disable_auto()
  if exists('#Wildsearch')
    augroup Wildsearch
      autocmd!
    augroup END
    augroup! Wildsearch
  endif
endfunction

function! wildsearch#main#start_auto()
  let s:auto = 1

  call wildsearch#main#start()
endfunction

function! wildsearch#main#stop_auto()
  if !s:active
    return
  endif

  let s:auto = 0

  call wildsearch#main#stop()
endfunction

function! wildsearch#main#start_manual()
  call wildsearch#main#start(0)

  return ''
endfunction

function! wildsearch#main#start(...)
  if has('nvim') && !s:init
    let s:init = 1
    call _wildsearch_init({'num_workers': s:opts.num_workers})
  endif

  if !exists('s:timer')
    let s:timer = timer_start(s:opts.interval,
          \ {_ -> wildsearch#main#do_with_check_context()}, {'repeat': -1})
  endif

  let s:active = 1
  let s:candidates = []
  let s:selected = -1
  let s:completion = ''
  let s:page = [-1, -1]

  if has_key(s:opts, 'pre_hook')
    if s:opts.post_hook ==# ''
      " pass
    elseif type(s:opts.pre_hook) == v:t_string
      call function(s:opts.pre_hook)()
    else
      call s:opts.pre_hook()
    endif
  endif

  call wildsearch#render#init()
  call wildsearch#render#exe_hl()

  let l:check = a:0 > 0 ? a:1 : 1
  if l:check
    call wildsearch#main#do_with_check_context()
  else
    call wildsearch#main#do()
  endif
endfunction

function! wildsearch#main#stop()
  if exists('s:timer')
    call timer_stop(s:timer)
    unlet s:timer
  endif

  let s:active = 0

  if exists('s:previous_cmdline')
    unlet s:previous_cmdline
  endif

  if has_key(s:opts, 'post_hook')
    if s:opts.post_hook ==# ''
      " pass
    elseif type(s:opts.post_hook) == v:t_string
      call function(s:opts.post_hook)()
    else
      call s:opts.post_hook()
    endif
  endif
endfunction

function! wildsearch#main#do_with_check_context()
  if !wildsearch#main#in_context()
    call wildsearch#main#stop()
    return
  endif

  call wildsearch#main#do()
endfunction

function! wildsearch#main#do()
  if !s:active
    return
  endif

  let l:input = getcmdline()

  let l:has_completion = !empty(s:completion) && l:input ==# s:completion
  let l:is_new_input = !exists('s:previous_cmdline')
  let l:input_changed = exists('s:previous_cmdline') && s:previous_cmdline !=# l:input

  " if !s:auto && !l:has_completion && l:input_changed
    " call wildsearch#main#stop()
    " return
  " endif

  let s:draw_done = 0

  if !l:has_completion && (l:input_changed || l:is_new_input)
    let s:previous_cmdline = l:input

    let l:ctx = {
        \ 'on_finish': 'wildsearch#main#on_finish',
        \ 'on_error': 'wildsearch#main#on_error',
        \ 'run_id': s:run_id,
        \ }

    let s:run_id += 1

    call wildsearch#pipeline#start(l:ctx, l:input)
  endif

  let l:ctx = {
        \ 'selected': s:selected,
        \ 'direction': 0,
        \ 'done': s:run_id - 1 == s:result_run_id,
        \ }

  if !s:draw_done && (l:is_new_input || wildsearch#render#need_redraw(l:ctx, s:candidates))
    call wildsearch#main#draw()
  endif
endfunction

function! wildsearch#main#on_finish(ctx, x)
  if !s:active
    return
  endif

  if a:ctx.run_id < s:result_run_id
    return
  endif

  let s:result_run_id = a:ctx.run_id

  let s:candidates = a:x is v:false ? [] : a:x
  let s:selected = -1
  " keep previous completion

  call wildsearch#main#draw()
endfunction

function! wildsearch#main#on_error(ctx, x)
  if !s:active
    return
  endif

  if a:ctx.run_id < s:result_run_id
    return
  endif

  let s:result_run_id = a:ctx.run_id

  call setwinvar(0, '&statusline', 'E:' . a:ctx.run_id . ':' . split(reltimestr(reltime(a:ctx.start_time)))[0] . ': ' . a:x)
  redrawstatus
endfunction

function! wildsearch#main#draw(...)
  let s:draw_done = 1

  let l:direction = a:0 == 0 ? 0 : a:1

  let l:ctx = {
        \ 'selected': s:selected,
        \ 'direction': l:direction,
        \ 'done': s:run_id - 1 == s:result_run_id,
        \ }

  let l:space_used = wildsearch#render#space_used(l:ctx, s:candidates)
  let l:ctx.space = winwidth(0) - l:space_used
  let l:ctx.page = s:page

  let s:page = wildsearch#render#make_page(l:ctx, s:candidates)
  let l:ctx.page = s:page

  let l:statusline = wildsearch#render#draw(l:ctx, s:candidates)

  call setwinvar(0, '&statusline', l:statusline)
  redrawstatus
endfunction

function! wildsearch#main#step(num_steps)
  let l:len = len(s:candidates)
  if l:len == 0
    let s:selected = -1
    let s:completion = ''
  elseif l:len == 1
    let s:selected = 0
    let s:completion = s:candidates[0]
  else
    if s:selected < 0 && a:num_steps < 0
      let s:selected = 0
    endif

    let l:selected = s:selected + a:num_steps

    while l:selected < 0
      let l:selected += l:len
    endwhile

    let s:selected = l:selected % l:len
    let s:completion = s:candidates[s:selected]
  endif

  call wildsearch#main#draw(a:num_steps)

  if s:selected != -1
    let l:keys = "\<C-E>\<C-U>"

    let l:candidates = s:candidates[s:selected]

    let l:i = 0
    while l:i < len(l:candidates)
      if match(l:candidates[l:i], '[\x00-\x1F]') >= 0
        let l:keys .= "\<C-Q>"
      endif

      let l:keys .= l:candidates[l:i]

      let l:i += 1
    endwhile

    call feedkeys(l:keys, 'n')
  endif

  return ''
endfunction

function! wildsearch#main#save_statusline()
  let s:old_laststatus = &laststatus
  let &laststatus = 2

  let s:old_statusline = &statusline
endfunction

function! wildsearch#main#restore_statusline()
  let &laststatus = s:old_laststatus
  let &statusline = s:old_statusline
  redrawstatus
endfunction

function! wildsearch#main#active()
  return s:active
endfunction
