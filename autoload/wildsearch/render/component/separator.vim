let s:index = 0

function! wildsearch#render#component#separator#make(str, fg, bg)
  let l:index = s:index
  let s:index += 1

  let l:name = 'WildsearchSeparator' . l:index

  return {
        \ 'stl': a:str,
        \ 'hl': l:name,
        \ 'on_start': {_ -> s:hl(l:name, a:fg, a:bg)}
        \ }
endfunction

function! s:hl(name, fg, bg)
  let l:fg_hl = wildsearch#render#get_colors(a:fg)
  let l:bg_hl = wildsearch#render#get_colors(a:bg)

  let l:cterm_hl = {}
  let l:gui_hl = {}

  if get(l:fg_hl[1], 'reverse', 0)
    let l:cterm_hl.foreground = get(l:fg_hl[1], 'foreground', 'NONE')
  else
    let l:cterm_hl.foreground = get(l:fg_hl[1], 'background', 'NONE')
  endif

  if get(l:bg_hl[1], 'reverse', 0)
    let l:cterm_hl.background = get(l:bg_hl[1], 'foreground', 'NONE')
  else
    let l:cterm_hl.background = get(l:bg_hl[1], 'background', 'NONE')
  endif

  if get(l:fg_hl[2], 'reverse', 0)
    let l:gui_hl.foreground = get(l:fg_hl[2], 'foreground', 'NONE')
  else
    let l:gui_hl.foreground = get(l:fg_hl[2], 'background', 'NONE')
  endif

  if get(l:bg_hl[2], 'reverse', 0)
    let l:gui_hl.background = get(l:bg_hl[2], 'foreground', 'NONE')
  else
    let l:gui_hl.background = get(l:bg_hl[2], 'background', 'NONE')
  endif

  let l:colors = [{}, l:cterm_hl, l:gui_hl]

  call wildsearch#render#make_hl(a:name, l:colors)
endfunction
