function! wilder#renderer#item#wildmenu_spinner#make(args) abort
  let l:frames = get(a:args, 'frames', ['-', '\', '|', '/'])
  if type(l:frames) is v:t_string
    let l:frames = split(l:frames, '\zs')
  endif

  let l:Done = get(a:args, 'done', '·')

  let l:spinner = wilder#renderer#spinner#make({
        \ 'num_frames': len(l:frames),
        \ 'delay': get(a:args, 'delay', 100),
        \ 'interval': get(a:args, 'interval', 100),
        \ })

  let l:state = {
        \ 'frames': l:frames,
        \ 'current_frame': l:Done,
        \ 'done': l:Done,
        \ 'spinner': l:spinner,
        \ }

  return {
        \ 'value': {ctx, result -> s:spinner(l:state, ctx, result)},
        \ 'len': {ctx, result -> wilder#renderer#wildmenu#component_len(
        \   s:get_char(l:state, ctx, result), ctx, result)},
        \ 'hl': get(a:args, 'hl', ''),
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:pre_hook(state, ctx) abort
  call wilder#renderer#wildmenu#component_pre_hook(a:state.frames, a:ctx)
  call wilder#renderer#wildmenu#component_pre_hook(a:state.done, a:ctx)
endfunction

function! s:post_hook(state, ctx) abort
  call wilder#renderer#wildmenu#component_post_hook(a:state.frames, a:ctx)
  call wilder#renderer#wildmenu#component_post_hook(a:state.done, a:ctx)
endfunction

" Set current_char in here so it is consistent with the actual rendered
" char. Due to reltime(), the char might be changed since len is called
" earlier
function! s:get_char(state, ctx, result) abort
  let l:frame_index = a:state.spinner.spin(a:ctx, a:result)

  if l:frame_index == -1
    let a:state.current_frame = a:state.done
  else
    let a:state.current_frame = a:state.frames[l:frame_index]
  endif

  return a:state.current_frame
endfunction

function! s:spinner(state, ctx, result) abort
  return a:state.current_frame
endfunction
