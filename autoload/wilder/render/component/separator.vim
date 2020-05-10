let s:index = 0

function! wilder#render#component#separator#make(str, fg, bg, ...) abort
  if a:0 == 0
    let l:key = s:index
    let s:index += 1
  else
    let l:key = a:1
  endif

  let l:name = 'WilderSeparator_' . l:key

  return {
        \ 'value': a:str,
        \ 'pre_hook': {ctx -> s:hl(l:name, a:fg, a:bg)},
        \ 'hl': l:name,
        \ }
endfunction

function! s:hl(name, from, to) abort
  let l:from_hl = wilder#render#get_colors(a:from)
  let l:to_hl = wilder#render#get_colors(a:to)

  let l:normal_hl = wilder#render#get_colors('Normal')
  let l:default_hl = [
        \ {},
        \ {
        \   'foreground': get(l:normal_hl[1], 'ctermfg', 7),
        \   'background': get(l:normal_hl[1], 'ctermbg', 0),
        \ },
        \ {
        \   'foreground': get(l:normal_hl[2], 'guifg', 'NONE'),
        \   'background': get(l:normal_hl[2], 'guibg', 'NONE'),
        \ }]

  let l:cterm_hl = {}
  let l:gui_hl = {}

  let l:colors = [{}, {}, {}]
  call s:get_hl(l:colors[1], l:from_hl[1], l:to_hl[1], l:default_hl[1], 1)
  call s:get_hl(l:colors[2], l:from_hl[2], l:to_hl[2], l:default_hl[2], 0)

  call wilder#make_hl(a:name, l:colors)
endfunction

function! s:get_hl(hl, from_hl, to_hl, default_hl, is_cterm) abort
  let l:from_hl_reverse = get(a:from_hl, 'reverse', 0) ||
        \ get(a:from_hl, 'standout', 0)
  let l:to_hl_reverse = get(a:to_hl, 'reverse', 0) ||
        \ get(a:to_hl, 'standout', 0)

  let l:default_fg = a:default_hl.foreground
  let l:default_bg = a:default_hl.background

  if l:from_hl_reverse
    let l:from_bg = get(a:from_hl, 'foreground', 'NONE')
    if l:from_bg ==# 'NONE'
      let l:from_bg = l:default_fg
    endif

    if a:is_cterm && get(a:from_hl, 'bold', 0) && l:from_bg < 8
      let l:from_bg += 8
    endif
  else
    let l:from_bg = get(a:from_hl, 'background', 'NONE')
    if l:from_bg ==# 'NONE'
      let l:from_bg = l:default_bg
    endif
  endif

  if l:to_hl_reverse
    let l:to_bg = get(a:to_hl, 'foreground', 'NONE')
    if l:to_bg ==# 'NONE'
      let l:to_bg = l:default_fg
    endif

    if a:is_cterm && get(a:to_hl, 'bold', 0) && l:to_bg < 8
      let l:to_bg += 8
    endif
  else
    let l:to_bg = get(a:to_hl, 'background', 'NONE')
    if l:to_bg ==# 'NONE'
      let l:to_bg = l:default_bg
    endif
  endif

  let a:hl.foreground = l:from_bg
  let a:hl.background = l:to_bg
endfunction
