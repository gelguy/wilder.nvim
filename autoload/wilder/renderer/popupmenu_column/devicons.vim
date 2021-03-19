function! wilder#renderer#popupmenu_column#devicons#make(opts) abort
  let l:state = {
        \ 'padding': get(a:opts, 'padding', [0, 1]),
        \ }

  return {ctx, result -> s:devicons(l:state, ctx, result)}
endfunction

function! s:devicons(state, ctx, result) abort
  let l:expand = get(a:result.data, 'cmdline.expand', '')

  if l:expand !=# 'file' &&
        \ l:expand !=# 'file_in_path' &&
        \ l:expand !=# 'dir' &&
        \ l:expand !=# 'shellcmd' &&
        \ l:expand !=# 'buffer'
    return ''
  endif

  let l:left_padding = repeat(' ', a:state.padding[0])
  let l:right_padding = repeat(' ', a:state.padding[1])

  let l:slash = !has('win32') && !has('win64')
        \ ? '/'
        \ : &shellslash
        \ ? '/'
        \ : '\'

  let [l:start, l:end] = a:ctx.page

  let l:icons = repeat([0], l:end - l:start + 1)

  let l:i = l:start
  while l:i <= l:end
    let l:x = a:result.value[l:i]

    let l:is_dir = l:x[-1:] ==# l:slash || l:x[-1:] ==# '/'

    let l:index = l:i - l:start
    let l:icons[l:index] = [[l:left_padding . WebDevIconsGetFileTypeSymbol(l:x, l:is_dir) . l:right_padding]]

    let l:i += 1
  endwhile

  return l:icons
endfunction
