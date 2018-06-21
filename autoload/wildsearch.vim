let s:async_sentinel = {}
let s:exit_sentinel = {}

function! wildsearch#exit()
  return s:exit_sentinel
endfunction

function! wildsearch#async_exit()
  return s:async_sentinel
endfunction

function! wildsearch#add(i)
  return {ctx, x -> a:i + x }
endfunction

function! wildsearch#times(i)
  return {ctx, x -> a:i * x }
endfunction

function! wildsearch#sleep(t)
  function! s:_f(ctx, x) closure
    call _wildsearch_sleep(a:ctx, a:t, a:x)
    return wildsearch#async_exit()
  endfunction
  return funcref('s:_f')
endfunction

function! wildsearch#set_pipeline(pipeline)
  let s:pipeline = a:pipeline
endfunction

function! wildsearch#start(x)
  let g:a = reltime()
  call wildsearch#pipeline({'step': 0}, a:x)
endfunction

function! wildsearch#next(ctx, x)
  call wildsearch#pipeline({'step': a:ctx.step + 1}, a:x)
endfunction

function! wildsearch#pipeline(ctx, x)
  let l:ctx = {'step': a:ctx.step}

  while l:ctx.step < len(s:pipeline)
    let l:res = wildsearch#call(l:ctx, a:x)

    if l:res is s:async_sentinel
      echom 'Async call'
      return
    elseif l:res is s:exit_sentinel
      echom 'Early exit'
      return
    endif

    let l:ctx = {'step': l:ctx.step + 1}
  endwhile

  call wildsearch#finish(a:x)
endfunction

function! wildsearch#call(ctx, x)
  return s:pipeline[a:ctx.step](a:ctx, a:x)
endfunction

function! wildsearch#finish(x)
  let &statusline = 'Result :' + string(a:x)
  echom reltimestr(reltime(g:a))
endfunction

let s:pipeline = [wildsearch#add(1), wildsearch#times(2), wildsearch#sleep(3), wildsearch#add(1)]
