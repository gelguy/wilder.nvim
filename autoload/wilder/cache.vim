function! wilder#cache#cache() abort
  return {
        \ '_cache': {},
        \ 'get': funcref('s:get'),
        \ 'set': funcref('s:set'),
        \ 'has_key': funcref('s:has_key'),
        \ 'clear': funcref('s:clear'),
        \ }
endfunction

function! s:get(key) dict abort
  return self['_cache'][a:key]
endfunction

function! s:set(key, value) dict abort
  let self['_cache'][a:key] = a:value
endfunction

function! s:has_key(key) dict abort
  return has_key(self['_cache'], a:key)
endfunction

function! s:clear() dict abort
  let self['_cache'] = {}
endfunction

function! wilder#cache#mru_cache(size) abort
  return {
        \ '_cache': {},
        \ '_queue': [],
        \ '_size': a:size,
        \ 'get': funcref('s:mru_get'),
        \ 'set': funcref('s:mru_set'),
        \ 'has_key': funcref('s:has_key'),
        \ 'clear': funcref('s:mru_clear'),
        \ 'mru_update': funcref('s:mru_update'),
        \ }
endfunction

function! s:mru_get(key) dict abort
  call self.mru_update(a:key)
  return self['_cache'][a:key]
endfunction

function! s:mru_set(key, value) dict abort
  let self['_cache'][a:key] = a:value

  call self.mru_update(a:key)
endfunction

function! s:mru_clear() dict abort
  let self['_cache'] = {}
  let self['_queue'] = []
endfunction

function! s:mru_update(key) dict abort
  let l:queue = self['_queue']

  let l:index = index(l:queue, a:key)
  if l:index == -1
    call insert(l:queue, a:key)

    if len(l:queue) > self['_size']
      let l:removed = remove(l:queue, -1)

      unlet self['_cache'][l:removed]
    endif
  elseif l:index > 0
    let self['_queue'] = [a:key] + l:queue[0 : l:index-1] + l:queue[l:index+1 :]
  endif
endfunction
