function! wilder#renderer#popupmenu_column#buffer_flags#make(opts) abort
  let l:flags = get(a:opts, 'flags', '1 %a-+ ')

  if empty(l:flags)
    return {-> ''}
  endif

  let l:state = {
        \ 'flags': l:flags,
        \ 'cache': wilder#cache#cache(),
        \ 'session_id': -1,
        \ }

  if has_key(a:opts, 'hl')
    let l:state.hl = a:opts.hl
  endif

  if has_key(a:opts, 'selected_hl')
    let l:state.selected_hl = a:opts.selected_hl
  endif

  return {ctx, result -> s:buffer_status(l:state, ctx, result)}
endfunction

function! s:buffer_status(state, ctx, result) abort
  let l:expand = get(a:result.data, 'cmdline.expand', '')

  if l:expand !=# 'buffer' && l:expand !=# 'file'
    return ''
  endif

  let l:flags = a:state.flags

  let l:session_id = a:ctx.session_id
  if a:state.session_id != l:session_id
    call a:state.cache.clear()
    let a:state.session_id = l:session_id
  endif

  let [l:start, l:end] = a:ctx.page
  " [current, modified]
  let l:buffer_status = repeat([0], l:end - l:start + 1)

  let l:width = len(l:flags)

  if stridx(l:flags, '1') != -1
    let l:bufnr_width = strdisplaywidth(bufnr('$'))
    let l:width += l:bufnr_width - 1
  endif

  let l:hl = get(a:state, 'hl', a:ctx.highlights['default'])
  let l:selected_hl = get(a:state, 'selected_hl', a:ctx.highlights['selected'])

  let l:empty_chunks = [[repeat(' ', l:width), l:hl, l:selected_hl]]

  let l:i = l:start
  while l:i <= l:end
    let l:index = l:i - l:start

    let l:x = fnamemodify(simplify(a:result.value[l:i]), ':~')

    if a:state.cache.has_key(l:x)
      let l:buffer_status[l:index] = a:state.cache.get(l:x)
      let l:i += 1
      continue
    endif

    let l:bufnr = bufnr('^' . l:x . '$')

    if l:bufnr == -1
      call a:state.cache.set(l:x, l:empty_chunks)
      let l:buffer_status[l:index] = l:empty_chunks
      let l:i += 1
      continue
    endif

    let l:status = ''

    let l:j = 0
    while l:j < l:width
      let l:char = l:flags[l:j]

      if l:char ==# ' '
        let l:status .= ' '
      elseif l:char ==# '1'
        let l:status .= repeat(' ', l:bufnr_width - strdisplaywidth(l:bufnr))
        let l:status .= l:bufnr
      elseif l:char ==# '%'
        if l:bufnr == bufnr('%')
          let l:status .= '%'
        elseif l:bufnr == bufnr('#')
          let l:status .= '#'
        else
          let l:status .= ' '
        endif
      elseif l:char ==# '+'
        let l:status .= nvim_buf_get_option(l:bufnr, 'modified') ?  '+' : ' '
      elseif l:char ==# '-'
        let l:status .= nvim_buf_get_option(l:bufnr, 'readonly') ? '=' :
              \ !nvim_buf_get_option(l:bufnr, 'modifiable') ? '-' : ' '
      elseif l:char ==# 'a'
        if bufloaded(l:bufnr)
          let l:is_active = !empty(win_findbuf(l:bufnr))
          let l:status .= l:is_active ? 'a' : 'h'
        else
          let l:status .= ' '
        endif
      endif

      let l:chunks = [[l:status, l:hl, l:selected_hl]]
      call a:state.cache.set(l:x, l:chunks)
      let l:buffer_status[l:index] = l:chunks

      let l:j += 1
    endwhile

    let l:i += 1
  endwhile

  return l:buffer_status
endfunction
