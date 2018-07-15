let s:index = 0

function! wildsearch#render#component#separator#make(str, fg, bg)
  let l:index = s:index
  let s:index += 1

  let l:name = 'WildsearchSeparator' . l:index

  return {
        \ 'stl': a:str,
        \ 'hl': l:name,
        \ 'on_start': {ctx -> s:hl(l:name, a:fg, a:bg)}
        \ }
endfunction

function! s:hl(name, from, to)
  let l:from_hl = wildsearch#render#get_colors(a:from)
  let l:to_hl = wildsearch#render#get_colors(a:to)

  let l:cterm_hl = {}
  let l:gui_hl = {}

  if get(l:from_hl[1], 'reverse', 0)
    let l:cterm_hl.foreground = get(l:from_hl[1], 'foreground', 'NONE')
  else
    let l:cterm_hl.foreground = get(l:from_hl[1], 'background', 'NONE')
  endif

  if get(l:to_hl[1], 'reverse', 0)
    let l:cterm_hl.background = get(l:to_hl[1], 'foreground', 'NONE')
  else
    let l:cterm_hl.background = get(l:to_hl[1], 'background', 'NONE')
  endif

  if get(l:from_hl[2], 'reverse', 0)
    let l:gui_hl.foreground = get(l:from_hl[2], 'foreground', 'NONE')
  else
    let l:gui_hl.foreground = get(l:from_hl[2], 'background', 'NONE')
  endif

  if get(l:to_hl[2], 'reverse', 0)
    let l:gui_hl.background = get(l:to_hl[2], 'foreground', 'NONE')
  else
    let l:gui_hl.background = get(l:to_hl[2], 'background', 'NONE')
  endif

  let l:colors = [{}, l:cterm_hl, l:gui_hl]

  call wildsearch#render#make_hl(a:name, l:colors)
endfunction
