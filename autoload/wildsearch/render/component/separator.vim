let s:index = 0

function! wildsearch#render#component#separator#make(str, from_hl, to_hl)
  let l:index = s:index
  let s:index += 1

  let l:name = 'WildsearchSeparator' . l:index

  return {
        \ 'stl': a:str,
        \ 'hl': {-> s:hl(l:name, a:from_hl, a:to_hl)}
        \ }
endfunction

function! s:hl(name, from_hl, to_hl)
  let l:from_bg = wildsearch#render#get_background_colors(a:from_hl)
  let l:to_bg = wildsearch#render#get_background_colors(a:to_hl)

  let l:colors = [[l:from_bg[0], l:to_bg[0]], [l:from_bg[1], l:to_bg[1]]]

  return wildsearch#render#make_hl(a:name, l:colors)
endfunction
