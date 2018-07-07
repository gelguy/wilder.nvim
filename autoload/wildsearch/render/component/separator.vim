let s:index = 0

function! wildsearch#render#component#separator#make(str, fg, bg)
  let l:index = s:index
  let s:index += 1

  let l:name = 'WildsearchSeparator' . l:index

  return {
        \ 'stl': a:str,
        \ 'hl': {_ -> s:hl(l:name, a:fg, a:bg)}
        \ }
endfunction

function! s:hl(name, fg, bg)
  let l:fg_hl = wildsearch#render#get_colors(a:fg)
  let l:bg_hl = wildsearch#render#get_colors(a:bg)

  let l:colors = [[l:fg_hl[0][1], l:bg_hl[0][1]], [l:fg_hl[1][1], l:bg_hl[1][1]]]

  return wildsearch#render#make_hl(a:name, l:colors)
endfunction
