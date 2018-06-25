function! wildsearch#pipeline#component#python_search#make(opts)
  return {ctx, x -> s:search(a:opts, ctx, x)}
endfunction

function! s:search(opts, ctx, x)
  if get(a:opts, 'sync', 0)
    return _wildsearch_python_search_sync(a:opts, a:ctx, a:x)
  endif

  call _wildsearch_python_search_async(a:opts, a:ctx, a:x)
  return v:null
endfunction

" function! s:search(opts, ctx, x)
  " let g:_wildsearch_use_re2 = has_key(a:opts, 'engine') && a:opts.engine == 're2'
  " python << EOF
" import vim
" if vim.vars['_wildsearch_use_re2']:
  " import re2 as re
" else:
  " import re
" query = vim.eval('a:x')
" buffer = "\n".join(vim.current.buffer[:])
" candidates = []
" try:
  " for match in re.finditer(query, buffer):
    " candidates.append(match.group())
" except:
  " candidates = []
" vim.vars["_wildsearch_candidates"] = candidates
" EOF
  " let candidates = g:_wildsearch_candidates
  " unlet g:_wildsearch_candidates
  " return candidates
" endfunction
