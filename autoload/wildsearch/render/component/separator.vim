let s:index = 0

function! wildsearch#render#component#separator#make(str, from_hl, to_hl)
  let l:index = s:index
  let s:index += 1

  let l:name = 'WildsearchSeparator' . l:index

  return {
        \ 'stl': a:str,
        \ 'hl': {_ -> s:hl(l:name, a:from_hl, a:to_hl)}
        \ }
endfunction

function! s:hl(name, from_hl, to_hl)
  let l:from = wildsearch#render#get_colors(a:from_hl)
  let l:to = wildsearch#render#get_colors(a:to_hl)

  let l:colors = [[l:from[0][1], l:to[0][1]], [l:from[1][1], l:to[1][1]]]

  return wildsearch#render#make_hl(a:name, l:colors)
endfunction
