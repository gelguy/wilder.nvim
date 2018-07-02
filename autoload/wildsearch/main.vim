scriptencoding utf-8

let s:running = 0
let s:run_id = 0
let s:result_run_id = 0

let s:candidates = []
let s:selected = -1
let s:selection = ''
let s:page = [-1, -1]

let s:opts = {
      \ 'separator': ' ',
      \ }

function! wildsearch#main#set_option(key, value)
  let s:opts[a:key] = a:value
endfunction

function! wildsearch#main#set_options(opts)
  let s:opts = extend(s:opts, a:opts)
endfunction

function! wildsearch#main#init()
  if !exists('#Wildsearch')
    augroup Wildsearch
      autocmd!
      autocmd CmdlineEnter * call wildsearch#main#start()
      autocmd CmdlineLeave * call wildsearch#main#stop()
    augroup END
  endif
endfunction

function! wildsearch#main#start(...)
  if !exists('s:timer')
    let s:timer = timer_start(100, function('wildsearch#main#do'), {'repeat': -1})
  endif

  call wildsearch#render#exe_hl()

  let s:candidates = []
  let s:selected = -1
  let s:selection = ''
  let s:page = [-1, -1]

  if has_key(s:opts, 'pre_hook')
    if type(s:opts.pre_hook) == v:t_string
      call function(s:opts.pre_hook)()
    else
      call s:opts.pre_hook()
    endif
  endif

  call wildsearch#main#do()
endfunction

function! wildsearch#main#stop()
  if !exists('s:timer')
    return
  endif

  if exists('s:previous_cmdline')
    unlet s:previous_cmdline
  endif

  if has_key(s:opts, 'post_hook')
    if type(s:opts.post_hook) == v:t_string
      call function(s:opts.post_hook)()
    else
      call s:opts.post_hook()
    endif
  endif

  call timer_stop(s:timer)
  unlet s:timer
endfunction

function! wildsearch#main#do(...)
  if !get(s:, 'timer', 0)
    return
  endif

  if getcmdtype() !=# '/'
    call wildsearch#main#stop()
    return
  endif

  let l:input = getcmdline()
  let g:a = l:input

  let l:has_selection = s:selection !=# '' && l:input ==# s:selection
  let l:cmdline_changed = !exists('s:previous_cmdline') || s:previous_cmdline != l:input

  if !l:has_selection && l:cmdline_changed
    let s:previous_cmdline = l:input

    let l:ctx = {
        \ 'on_finish': 'wildsearch#main#on_finish',
        \ 'on_error': 'wildsearch#main#on_error',
        \ 'run_id': s:run_id,
        \ }

    let s:run_id += 1

    call wildsearch#pipeline#start(l:ctx, l:input)
  endif
endfunction

function! wildsearch#main#on_finish(ctx, x)
  if !exists('s:timer')
    return
  endif

  if a:ctx.run_id < s:result_run_id
    return
  endif

  let s:result_run_id = a:ctx.run_id

  let s:candidates = a:x is v:false ? [] : a:x
  let s:selected = -1

  call wildsearch#main#draw()
endfunction

function! wildsearch#main#draw(...)
  let l:direction = a:0 == 0 ? 0 : a:1

  let l:ctx = {
        \ 'selected': s:selected,
        \ 'separator': s:opts.separator,
        \ 'direction': l:direction,
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

function! wildsearch#main#on_error(ctx, x)
  if !exists('s:timer')
    return
  endif

  if a:ctx.run_id < s:result_run_id
    return
  endif

  let s:result_run_id = a:ctx.run_id

  call setwinvar(0, '&statusline', 'E:' . a:ctx.run_id . ':' . split(reltimestr(reltime(a:ctx.start_time)))[0] . ': ' . a:x)
  redrawstatus
endfunction

function! wildsearch#main#step(num_steps)
  let l:len = len(s:candidates)
  if l:len == 0
    let s:selected = -1
  elseif l:len == 1
    let s:selected = 0
  else
    let l:selected = s:selected + a:num_steps

    while l:selected < 0
      let l:selected += l:len
    endwhile

    let s:selected = l:selected % l:len
    let s:selection = s:candidates[s:selected]
  endif

  call wildsearch#main#draw(a:num_steps)

  if s:selected != -1
    call feedkeys("\<C-E>\<C-U>" . s:candidates[s:selected], 'n')
  endif

  " returning '' seems to prevent the async completions from finishing
  return "\<Insert>\<Insert>"
endfunction

function! wildsearch#main#active()
  return exists('s:timer')
endfunction
