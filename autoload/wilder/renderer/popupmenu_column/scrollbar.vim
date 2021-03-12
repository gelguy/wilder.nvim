function! wilder#renderer#popupmenu_column#scrollbar#make(opts) abort
  let l:state = {
        \ 'cache': wilder#cache#cache(),
        \ 'run_id': -1,
        \ }

  let l:thumb_char = get(a:opts, 'thumb_char', '█')
  let l:thumb_hl = get(a:opts, 'thumb_hl', 'PmenuThumb')
  let l:scrollbar_char = get(a:opts, 'scrollbar_char', ' ')
  let l:scrollbar_hl = get(a:opts, 'scrollbar_hl', 'PmenuSbar')

  let l:state['thumb_chunk'] = [l:thumb_char, l:thumb_hl]
  let l:state['scrollbar_chunk'] = [l:scrollbar_char, l:scrollbar_hl]

  return {ctx, result, i -> s:scrollbar(l:state, ctx, result, i)}
endfunction

function! s:scrollbar(state, ctx, result, i) abort
  if a:state.run_id != a:ctx.run_id
    call a:state.cache.clear()
  endif

  let l:page = a:ctx.page

  if l:page == [-1, -1]
    return ''
  endif

  let [l:start, l:end] = l:page
  let l:num_candidates = len(a:result.value)
  let l:pum_height = l:end - l:start + 1

  if l:pum_height == l:num_candidates
    return ''
  endif

  let l:cache = a:state['cache']

  let l:key = l:start . ' ' . l:end . ' ' . l:num_candidates . ' ' . l:pum_height

  if !l:cache.has_key(l:key)
    let l:thumb_start = floor(1.0 * l:start * l:pum_height / l:num_candidates)
    let l:thumb_size = floor(1.0 * l:pum_height * l:pum_height / l:num_candidates) + 1
    let l:thumb_end = l:thumb_start + l:thumb_size

    call l:cache.set(l:key, [l:thumb_start, l:thumb_end])
  else
    let [l:thumb_start, l:thumb_end] = l:cache.get(l:key)
  endif

  let l:row = a:i - l:start
  if l:thumb_start <= l:row && l:thumb_end > l:row
    return [a:state['thumb_chunk']]
  endif

  return [a:state['scrollbar_chunk']]
endfunction
