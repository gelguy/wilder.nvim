function! wilder#renderer#popupmenu_column#buffer_status#make(opts) abort
  let l:state = copy(a:opts)
  let l:state.cache = wilder#cache#cache()
  let l:state.run_id = -1

  return {ctx, result -> s:buffer_status(l:state, ctx, result)}
endfunction

function! s:buffer_status(state, ctx, result) abort
  let l:expand = get(a:result.data, 'cmdline.expand', '')

  if l:expand !=# 'buffer' && l:expand !=# 'file'
    return ''
  endif

  let l:flags = get(a:state, 'flags', '1 %+ ')

  if empty(l:flags)
    return ''
  endif

  let l:run_id = a:ctx.run_id
  if a:state.run_id != l:run_id
    call a:state.cache.clear()
    let a:state.run_id = l:run_id
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

    let l:x = simplify(a:result.value[l:i])

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
