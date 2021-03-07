function! wilder#cache#cache()
  return {
        \ '_cache': {},
        \ 'get': funcref('s:get'),
        \ 'set': funcref('s:set'),
        \ 'has_key': funcref('s:has_key'),
        \ 'clear': funcref('s:clear'),
        \ }
endfunction

function! s:get(key) dict
  return self['_cache'][a:key]
endfunction

function! s:set(key, value) dict
  let self['_cache'][a:key] = a:value
endfunction

function! s:has_key(key) dict
  return has_key(self['_cache'], a:key)
endfunction

function! s:clear() dict
  let self['_cache'] = {}
endfunction
