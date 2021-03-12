function! wilder#pipe#history#make(...) abort
  let l:num_history = a:0 > 0 ? a:1 : 50
  let l:cmdtype = a:0 > 1 ? a:2 : ''
  return {ctx, x -> s:history(l:num_history, l:cmdtype)}
endfunction

function! s:history(num_history, cmdtype) abort
  let l:cmdtype = a:cmdtype ==# '' ? getcmdtype() : a:cmdtype
  let l:max = histnr(l:cmdtype)

  if a:num_history <= 0
    let l:num_history = l:max
  else
    let l:num_history = a:num_history > l:max ? l:max : a:num_history
  endif

  let l:res = []

  let l:i = 0
  while l:i < l:num_history
    let l:entry = histget(l:cmdtype, -(l:i + 1))
    if !empty(l:entry)
      call add(l:res, l:entry)
    endif

    let l:i += 1
  endwhile

  return l:res
endfunction
