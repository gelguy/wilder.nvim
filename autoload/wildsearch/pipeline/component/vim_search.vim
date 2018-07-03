function! wildsearch#pipeline#component#vim_search#make(opts)
  return {ctx, x -> s:search(a:opts, ctx, x)}
endfunction

function! s:search(opts, ctx, x)
  let l:cursor_pos = getcurpos()
  let l:candidates = {}
  let l:max_candidates = get(a:opts, 'max_candidates', 300)

  try
    silent exe 'keeppatterns %s/' . a:x . '/\=s:add(submatch(0), l:candidates, l:max_candidates)/gne'
  catch /^Wildsearch: Max candidates reached/
    return keys(l:candidates)
  catch
    return wildsearch#pipeline#do_error(a:ctx, v:exception)
  finally
    call setpos('.', l:cursor_pos)
  endtry

  return keys(l:candidates)
endfunction

function! s:add(match, candidates, max_candidates)
  let a:candidates[a:match] = 1

  if a:max_candidates > 0 && len(a:candidates) >= a:max_candidates
    call s:throw()
  endif
endfunction

function! s:throw()
  throw 'Wildsearch: Max candidates reached'
endfunction
