function! wildsearch#pipeline#component#python_search#make(opts)
  return {ctx, x -> wildsearch#pipeline#null(_wildsearch_python_search(a:opts, ctx, x))}
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
