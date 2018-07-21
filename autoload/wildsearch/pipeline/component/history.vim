function! wildsearch#pipeline#component#history#make(cmdtype, ...) abort
  let l:num_history = a:0 > 0 ? a:1 : 50
  return {ctx, x -> s:history(a:cmdtype, l:num_history)}
endfunction

function! s:history(cmdtype, num_history) abort
  let l:max = histnr(a:cmdtype)
  if a:num_history <= 0
    let l:num_history = l:max
  else
    let l:num_history = a:num_history > l:max ? l:max : a:num_history
  endif

  let l:res = []

  let l:i = 0
  while l:i < l:num_history
    let l:entry = histget(a:cmdtype, -(l:i + 1))
    if !empty(l:entry)
      call add(l:res, l:entry)
    endif

    let l:i += 1
  endwhile

  return l:res
endfunction
