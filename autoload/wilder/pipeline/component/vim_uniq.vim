function! wilder#pipeline#component#vim_uniq#make() abort
  return {ctx, x -> s:uniq(ctx, x)}
endfunction

function! s:uniq(ctx, x) abort
  let l:seen = {}
  let l:res = []

  for l:element in a:x
    if !has_key(l:seen, l:element)
      let l:seen[l:element] = 1
      call add(l:res, l:element)
    endif
  endfor

  return l:res
endfunction
