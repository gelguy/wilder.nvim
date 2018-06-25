function! wildsearch#pipeline#component#vim_search#make(opts)
  return {ctx, x -> s:search(a:opts, ctx, x)}
endfunction

function! s:search(opts, ctx, x)
  let l:cursor_pos = getcurpos()
  let l:candidates = []
  let l:callback = has_key(a:opts, 'max_candidates') && a:opts.max_candidates > 0 ?
        \ 'len(candidates) < ' . a:opts.max_candidates . ' ? ' .
        \   'add(candidates, submatch(0)) : ' .
        \   's:throw()' :
        \ 'add(candidates, submatch(0))'
  try
    silent exe 'keeppatterns %s/' . a:x . '/\=' . l:callback . '/gne'
  catch /^Wildsearch: Max candidates reached/
    return l:candidates
  catch
    return {'wildsearch_error': v:exception}
  finally
    call setpos('.', l:cursor_pos)
  endtry
  return l:candidates
endfunction

function! s:throw()
  throw 'Wildsearch: Max candidates reached'
endfunction
