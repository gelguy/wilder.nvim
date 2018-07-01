scriptencoding utf-8

function! wildsearch#loop#init()
  if !exists('#Wildsearch')
    augroup Wildsearch
      autocmd!
      autocmd CmdlineEnter * call wildsearch#loop#start()
      autocmd CmdlineLeave * call wildsearch#loop#stop()
    augroup END
  endif
endfunction

function! wildsearch#loop#start(...)
  if !exists('s:timer')
    call lightline#disable()

    call wildsearch#loop#main()
    let s:timer = timer_start(100, function('wildsearch#loop#main'), {'repeat': -1})
  endif

  call wildsearch#render#exe_hl()

  return ''
endfunction

function! wildsearch#loop#stop()
  if !exists('s:timer')
    return
  endif

  if exists('s:previous_cmdline')
    unlet s:previous_cmdline
  endif

  call lightline#enable()

  call timer_stop(s:timer)
  unlet s:timer
endfunction

let s:run_id = 0
let s:result_run_id = 0

function! wildsearch#loop#main(...)
  if !get(s:, 'timer', 0)
    return
  endif

  if getcmdtype() !=# '/'
    call wildsearch#loop#stop()
    return
  endif

  let l:input = getcmdline()
  let g:a = l:input

  let l:need_update = !exists('s:previous_cmdline') || s:previous_cmdline != l:input

  if l:need_update
    let s:previous_cmdline = l:input

    let l:ctx = {
        \ 'on_finish': 'wildsearch#loop#on_finish',
        \ 'on_error': 'wildsearch#loop#on_error',
        \ 'run_id': s:run_id,
        \ }

    let s:run_id += 1

    call wildsearch#pipeline#start(l:ctx, l:input)
  endif
endfunction

function! wildsearch#loop#on_finish(ctx, x)
  if !exists('s:timer')
    return
  endif

  if a:ctx.run_id < s:result_run_id
    return
  endif

  let s:result_run_id = a:ctx.run_id

  let l:separator = ' · '
  let l:candidates = a:x is v:false ? [] : a:x

  let l:ctx = {
        \ 'index': 0,
        \ 'selected': -1,
        \ 'space': winwidth(0),
        \ 'page': [-1, -1],
        \ 'separator': ' · ',
        \ }

  let l:space_used = wildsearch#render#space_used(l:ctx, l:candidates)
  let l:ctx.space = l:ctx.space - l:space_used

  let l:page = wildsearch#render#make_page(l:ctx, l:candidates)
  let l:ctx.page = l:page

  let l:statusline = wildsearch#render#draw(l:ctx, l:candidates)

  let &statusline = l:statusline
  redrawstatus
endfunction

function! wildsearch#loop#on_error(ctx, x)
  if !exists('s:timer')
    return
  endif

  if a:ctx.run_id < s:result_run_id
    return
  endif

  let s:result_run_id = a:ctx.run_id

  let &statusline = 'E:' . a:ctx.run_id . ':' . split(reltimestr(reltime(a:ctx.start_time)))[0] . ': ' . a:x
  redrawstatus
endfunction
