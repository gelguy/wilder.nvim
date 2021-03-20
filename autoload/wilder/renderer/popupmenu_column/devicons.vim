function! wilder#renderer#popupmenu_column#devicons#make(opts) abort
  let l:padding = get(a:opts, 'padding', [0, 1])
  let l:state = {
        \ 'session_id': -1,
        \ 'cache': wilder#cache#cache(),
        \ 'left_padding': repeat(' ', l:padding[0]),
        \ 'right_padding': repeat(' ', l:padding[1]),
        \ }

  if !has_key(a:opts, 'get_icon')
    let l:state.get_icon = 'WebDevIconsGetFileTypeSymbol'
  else
    let l:state.get_icon = a:opts.get_icon
  endif

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

  let l:session_id = a:ctx.session_id
  if a:state.session_id != l:session_id
    call a:state.cache.clear()
    let a:state.session_id = l:session_id
  endif

  let l:slash = !has('win32') && !has('win64')
        \ ? '/'
        \ : &shellslash
        \ ? '/'
        \ : '\'

  let [l:start, l:end] = a:ctx.page

  let l:icons = repeat([0], l:end - l:start + 1)

  let l:Get_icon = a:state.get_icon
  if type(l:Get_icon) is v:t_string
    let l:Get_icon = function(l:Get_icon)
  endif

  let l:i = l:start
  while l:i <= l:end
    let l:index = l:i - l:start

    let l:x = a:result.value[l:i]

    if a:state.cache.has_key(l:x)
      let l:icons[l:index] = a:state.cache.get(l:x)

      let l:i += 1
      continue
    endif

    let l:is_dir = l:x[-1:] ==# l:slash || l:x[-1:] ==# '/'

    let l:icon = l:Get_icon(l:x, l:is_dir)

    let l:chunks = [[a:state.left_padding . l:icon . a:state.right_padding]]
    call a:state.cache.set(l:x, l:chunks)

    let l:icons[l:index] = l:chunks

    let l:i += 1
  endwhile

  return l:icons
endfunction

function! s:get_guibg(hl) abort
  let l:gui_colors = wilder#highlight#get_hl(a:hl)[2]

  return get(l:gui_colors, 'reverse', 0) || get(l:gui_colors, 'standout', 0) ?
        \ l:gui_colors.foreground :
        \ l:gui_colors.background
endfunction

function! s:make_temp_hl(hl, guibg, selected) abort
  let l:name = a:selected ? 'WilderDeviconsSelected_' : 'WilderDevicons_'
  return wilder#make_temp_hl(l:name . a:hl, a:hl,
        \ [{}, {}, {'background': a:guibg}])
endfunction
