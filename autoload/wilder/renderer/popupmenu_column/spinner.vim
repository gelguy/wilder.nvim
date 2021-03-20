function! wilder#renderer#popupmenu_column#spinner#make(opts) abort
  let l:frames = get(a:opts, 'frames', ['-', '\', '|', '/'])
  if type(l:frames) is v:t_string
    let l:frames = split(l:frames, '\zs')
  endif

  let l:spinner = wilder#renderer#spinner#make({
        \ 'num_frames': len(l:frames),
        \ 'delay': get(a:opts, 'delay', 50),
        \ 'interval': get(a:opts, 'interval', 100),
        \ })

  let l:state = {
        \ 'frames': l:frames,
        \ 'done': get(a:opts, 'done', ' '),
        \ 'spinner': l:spinner,
        \ 'align': get(a:opts, 'align', 'bottom'),
        \ }

  if has_key(a:opts, 'hl')
    let l:state.hl = a:opts.hl
  endif

  if has_key(a:opts, 'selected_hl')
    let l:state.selected_hl = a:opts.selected_hl
  endif

  return {
        \ 'value': {ctx, result -> s:spinner(l:state, ctx, result)},
        \ }
endfunction

function! s:spinner(state, ctx, result) abort
  let [l:start, l:end] = a:ctx.page
  let l:height = l:end - l:start + 1

  let l:frame_number = a:state.spinner.spin(a:ctx, a:result)

  if l:frame_number == -1
    let l:frame = a:state.done
  else
    let l:frame = a:state.frames[l:frame_number]
  endif

  let l:column_chunks = repeat([[['']]], l:height)

  if a:state.align ==# 'bottom'
    let l:column_chunks[-1] = [[l:frame]]
  else
    let l:column_chunks[0] = [[l:frame]]
  endif

  return l:column_chunks
endfunction
