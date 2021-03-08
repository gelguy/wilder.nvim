scriptencoding utf-8

let s:hl_list = []
let s:has_strtrans_issue = strdisplaywidth('') != strdisplaywidth(strtrans(''))

function! wilder#render#draw_x(ctx, result, i)
  let l:x = a:result.value[a:i]

  if has_key(a:result, 'draw')
    let l:ctx = {
          \ 'i': a:i,
          \ 'selected': a:ctx.selected == a:i,
          \ }

    for l:F in a:result.draw
      if type(l:F) isnot v:t_func
        let l:F = function(l:F)
      endif

      let l:x = l:F(l:ctx, l:x, get(a:result, 'data', {}))
    endfor
  endif

  return wilder#render#to_printable(l:x)
endfunction

function! wilder#render#normalise_chunks(hl, chunks) abort
  if empty(a:chunks)
    return []
  endif

  let l:res = []

  let l:text = ''
  let l:hl = a:hl

  for l:chunk in a:chunks
    let l:chunk_hl = get(l:chunk, 1, a:hl)

    if l:chunk_hl ==# l:hl
      let l:text .= l:chunk[0]
    else
      if !empty(l:text)
        call add(l:res, [l:text, l:hl])
      endif

      let l:text = l:chunk[0]
      let l:hl = l:chunk_hl
    endif
  endfor

  call add(l:res, [l:text, l:hl])

  return l:res
endfunction

function! wilder#render#spans_to_chunks(str, spans, hl, span_hl) abort
  let l:res = []

  let l:non_span_start = 0
  let l:end = 0

  let l:i = 0
  while l:i < len(a:spans)
    let l:span = a:spans[l:i]
    let l:start = l:span[0]
    let l:len = l:span[1]

    if l:start > 0
      call add(l:res, [strpart(a:str, l:non_span_start, l:start - l:non_span_start), a:hl])
    endif

    call add(l:res, [strpart(a:str, l:start, l:len), a:span_hl])

    let l:non_span_start = l:start + l:len
    let l:i += 1
  endwhile

  call add(l:res, [strpart(a:str, l:non_span_start), a:hl])

  return l:res
endfunction

function! wilder#render#init_hl() abort
  for [l:name, l:x, l:xs] in s:hl_list
    call s:make_hl(l:name, l:x, l:xs)
  endfor
endfunction

function! wilder#render#make_hl(name, x, xs) abort
  let l:name = s:make_hl(a:name, a:x, a:xs)
  call filter(s:hl_list, {i, elem -> elem[0] !=# l:name})
  call add(s:hl_list, [l:name, deepcopy(a:x), deepcopy(a:xs)])
  return l:name
endfunction

function! s:make_hl(name, x, xs) abort
  let l:x = s:to_hl_list(a:x)

  for l:elem in a:xs
    let l:y = s:to_hl_list(l:elem)
    let l:x = s:combine_hl_list(l:x, l:y)
  endfor

  return s:make_hl_from_list(a:name, l:x)
endfunction

function! s:to_hl_list(x) abort
  if type(a:x) is v:t_string
    let l:x = wilder#render#get_colors(a:x)
  else
    let l:x = a:x
  endif

  if type(l:x[0]) is v:t_list
    return l:x
  endif

  let l:term_hl = s:get_attrs_as_list(l:x[0])

  let l:cterm_hl = [
        \ get(l:x[1], 'foreground', 'NONE'),
        \ get(l:x[1], 'background', 'NONE')
        \ ] + s:get_attrs_as_list(l:x[1])

  let l:gui_hl = [
        \ get(l:x[2], 'foreground', 'NONE'),
        \ get(l:x[2], 'background', 'NONE')
        \ ] + s:get_attrs_as_list(l:x[2])

  return [l:term_hl, l:cterm_hl, l:gui_hl]
endfunction

function! s:combine_hl_list(l, m) abort
  let l:term_hl = copy(a:l[0])
  let l:cterm_hl = copy(a:l[1])
  let l:gui_hl = copy(a:l[2])

  if len(l:term_hl) <= 2
    let l:term_hl = copy(a:m[0])
  else
    let l:term_hl += a:m[0][2:]
  endif

  if get(a:m[1], 0, 'NONE') !=# 'NONE'
    if empty(l:cterm_hl)
      let l:cterm_hl = [a:m[1][0]]
    else
      let l:cterm_hl[0] = a:m[1][0]
    endif
  endif

  if get(a:m[1], 1, 'NONE') !=# 'NONE'
    if empty(l:cterm_hl)
      let l:cterm_hl = ['NONE', a:m[1][1]]
    else
      let l:cterm_hl[1] = a:m[1][1]
    endif
  endif

  if len(a:m[1]) > 2
    if empty(l:cterm_hl)
      let l:cterm_hl = ['NONE', 'NONE'] + a:m[1][2:]
    else
      let l:cterm_hl += a:m[1][2:]
    endif
  endif

  if get(a:m[2], 0, 'NONE') !=# 'NONE'
    if empty(l:gui_hl)
      let l:gui_hl = [a:m[2][0]]
    else
      let l:gui_hl[0] = a:m[2][0]
    endif
  endif

  if get(a:m[2], 1, 'NONE') !=# 'NONE'
    if empty(l:gui_hl)
      let l:gui_hl = ['NONE', a:m[2][1]]
    else
      let l:gui_hl[1] = a:m[2][1]
    endif
  endif

  if len(a:m[2]) > 2
    if empty(l:gui_hl)
      let l:gui_hl = ['NONE', 'NONE'] + a:m[2][2:]
    else
      let l:gui_hl += a:m[2][2:]
    endif
  endif

  return [l:term_hl, l:cterm_hl, l:gui_hl]
endfunction

function! s:make_hl_from_list(name, args) abort
  let l:term_hl = a:args[0]
  let l:cterm_hl = a:args[1]
  let l:gui_hl = a:args[2]

  let l:cmd = 'hi! ' . a:name . ' '

  let l:term_attr = l:term_hl[2:]
  if len(l:term_hl) >= 2
    let l:cmd .= 'term=' . join(l:term_attr, ',') . ' '
  endif

  let l:cterm_attr = l:cterm_hl[2:]
  if !empty(l:cterm_attr)
    let l:cmd .= 'cterm=' . join(l:cterm_attr, ',') . ' '
  endif

  if len(l:cterm_hl) >= 1
    if l:cterm_hl[0] >= 0
      let l:cmd .= 'ctermfg=' . l:cterm_hl[0] . ' '
    endif

    if len(l:cterm_hl) >= 2 && l:cterm_hl[1] >= 0
      let l:cmd .= 'ctermbg=' . l:cterm_hl[1] . ' '
    endif
  endif

  let l:gui_attr = l:gui_hl[2:]
  if !empty(l:gui_attr)
    let l:cmd .= 'gui=' . join(l:gui_attr, ',') . ' '
  endif

  if len(l:gui_hl) >= 1
    if type(l:gui_hl[0]) == v:t_number
      let l:cmd .= 'guifg=' . printf('#%06x', l:gui_hl[0]) . ' '
    else
      let l:cmd .= 'guifg=' . l:gui_hl[0] . ' '
    endif

    if len(l:gui_hl) >= 2
      if type(l:gui_hl[1]) == v:t_number
        let l:cmd .= 'guibg=' . printf('#%06x', l:gui_hl[1]) . ' '
      else
        let l:cmd .= 'guibg=' . l:gui_hl[1] . ' '
      endif
    endif
  endif

  exe l:cmd
  return a:name
endfunction

function! s:get_attrs_as_list(attrs) abort
  let l:res = []

  if get(a:attrs, 'bold', 0)
    call add(l:res, 'bold')
  endif
  if get(a:attrs, 'underline', 0)
    call add(l:res, 'underline')
  endif
  if get(a:attrs, 'undercurl', 0)
    call add(l:res, 'undercurl')
  endif
  if get(a:attrs, 'strikethrough', 0)
    call add(l:res, 'strikethrough')
  endif
  if get(a:attrs, 'reverse', 0) ||
        \ get(a:attrs, 'inverse', 0)
    call add(l:res, 'reverse')
  endif
  if get(a:attrs, 'italic', 0)
    call add(l:res, 'italic')
  endif
  if get(a:attrs, 'standout', 0)
    call add(l:res, 'standout')
  endif

  return l:res
endfunction

function! wilder#render#get_colors(group) abort
  if has('nvim')
    return wilder#render#get_colors_nvim(a:group)
  else
    return wilder#render#get_colors_vim(a:group)
  endif
endfunction

function! wilder#render#get_colors_nvim(group) abort
  try
    let l:cterm_hl = nvim_get_hl_by_name(a:group, 0)
    let l:gui_hl = nvim_get_hl_by_name(a:group, 1)

    return [{}, l:cterm_hl, l:gui_hl]
  catch
    return [{}, {}, {}]
  endtry
endfunction

function! wilder#render#get_colors_vim(group) abort
  try
    let l:highlight = execute('silent highlight ' . a:group)

    let l:link_matches = matchlist(l:highlight, 'links to \(\S\+\)')
     " follow the link
    if len(l:link_matches) > 0
      return wilder#render#get_colors_vim(l:link_matches[1])
    endif

    let l:term_hl = {}
    if match(l:highlight, 'term=\S*') >= 0
      call s:get_hl_attrs(l:term_hl, 'term', l:highlight)
    endif

    let l:cterm_hl = {}
    if match(l:highlight, 'cterm=\S*') >= 0
      call s:get_hl_attrs(l:cterm_hl, 'cterm', l:highlight)
    endif

    let l:cterm_hl.background = get(matchlist(l:highlight, 'ctermbg=\([0-9A-Za-z]\+\)'), 1, 'NONE')
    let l:cterm_hl.foreground = get(matchlist(l:highlight, 'ctermfg=\([0-9A-Za-z]\+\)'), 1, 'NONE')

    let l:gui_hl = {}
    if match(l:highlight, 'gui=\S*') >= 0
      call s:get_hl_attrs(l:gui_hl, 'gui', l:highlight)
    endif

    let l:gui_hl.background = get(matchlist(l:highlight, 'guibg=\([#0-9A-Za-z]\+\)'), 1, 'NONE')
    let l:gui_hl.foreground = get(matchlist(l:highlight, 'guifg=\([#0-9A-Za-z]\+\)'), 1, 'NONE')

    return [l:term_hl, l:cterm_hl, l:gui_hl]
  catch
    return [{}, {}, {}]
  endtry
endfunction

function! s:get_hl_attrs(attrs, key, hl) abort
  let l:prefix = ' ' . a:key . '=\S*'
  let a:attrs.bold = match(a:hl, l:prefix . 'bold') >= 0
  let a:attrs.underline = match(a:hl, l:prefix . 'underline') >= 0
  let a:attrs.undercurl = match(a:hl, l:prefix . 'undercurl') >= 0
  let a:attrs.strikethrough = match(a:hl, l:prefix . 'strikethrough') >= 0
  let a:attrs.reverse = match(a:hl, l:prefix . 'reverse') >= 0 ||
        \ match(a:hl, l:prefix . 'inverse') >= 0
  let a:attrs.italic = match(a:hl, l:prefix . 'italic') >= 0
  let a:attrs.standout = match(a:hl, l:prefix . 'standout') >= 0
endfunction

function! wilder#render#to_printable(x) abort
  if !s:has_strtrans_issue
    " check if first character is a combining character
    if strdisplaywidth(' ' . a:x) == strdisplaywidth(a:x)
      return strtrans(' ' . a:x)
    endif

    return strtrans(a:x)
  endif

  let l:transformed = strtrans(a:x)
  " strtrans is ok
  if strdisplaywidth(a:x) == strdisplaywidth(l:transformed)
    " check if first character is a combining character
    if strdisplaywidth(' ' . a:x) == strdisplaywidth(a:x)
      return strtrans(' ' . a:x)
    endif

    return strtrans(a:x)
  endif

  let l:res = ''
  let l:first = 1

  for l:char in split(a:x, '\zs')
    let l:transformed_char = strtrans(l:char)

    let l:transformed_width = strdisplaywidth(l:transformed_char)
    let l:width = strdisplaywidth(l:char)

    if l:transformed_width == l:width
      " strtrans is ok
      let l:res .= l:transformed_char
    elseif l:transformed_width == 0
      " strtrans returns empty character, use original char
      if l:first && strdisplaywidth(' ' . l:char) == strdisplaywidth(l:char)
        " check if first character is combining character
        let l:res .= ' ' . l:char
      else
        let l:res .= l:char
      endif
    else
      " fallback to hex representation
      let l:res .= '<' . printf('%02x', char2nr(l:char)) . '>'
    endif

    let l:first = 0
  endfor

  return l:res
endfunction

function! wilder#render#truncate(len, x) abort
  if a:len <= 0
    return ''
  endif

  let l:width = strdisplaywidth(a:x)
  let l:chars = split(a:x, '\zs')
  let l:index = len(l:chars) - 1

  while l:width > a:len && l:index >= 0
    let l:width -= strdisplaywidth(l:chars[l:index])

    let l:index -= 1
  endwhile

  return join(l:chars[:l:index], '')
endfunction

function! wilder#render#truncate_chunks(len, xs) abort
  if a:len <= 0
    return []
  endif

  let l:width = 0
  let l:res = []
  let l:i = 0

  while l:i < len(a:xs)
    let l:chunk = a:xs[l:i]
    let l:chunk_width = strdisplaywidth(l:chunk[0])

    if l:width + l:chunk_width > a:len
      call add(l:res, [wilder#render#truncate(a:len - l:width, l:chunk[0]), l:chunk[1]])
      return l:res
    endif

    call add(l:res, l:chunk)
    let l:width += l:chunk_width
    let l:i += 1
  endwhile

  return l:res
endfunction

function! wilder#render#chunks_displaywidth(chunks) abort
  let l:width = 0

  for l:chunk in a:chunks
    let l:width += strdisplaywidth(l:chunk[0])
  endfor

  return l:width
endfunction

function! wilder#render#apply_highlights(apply_highlights, data, x)
  for l:Apply_highlights in a:apply_highlights
    let l:spans = l:Apply_highlights({}, a:data, a:x)
    if l:spans isnot 0
      return l:spans
    endif
  endfor

  return 0
endfunction

let s:high_control_characters = {
      \ '': '^?',
      \ '': '<80>',
      \ '': '<81>',
      \ '': '<82>',
      \ '': '<83>',
      \ '': '<84>',
      \ '': '<85>',
      \ '': '<86>',
      \ '': '<87>',
      \ '': '<88>',
      \ '': '<89>',
      \ '': '<8a>',
      \ '': '<8b>',
      \ '': '<8c>',
      \ '': '<8d>',
      \ '': '<8e>',
      \ '': '<8f>',
      \ '': '<90>',
      \ '': '<91>',
      \ '': '<92>',
      \ '': '<93>',
      \ '': '<94>',
      \ '': '<95>',
      \ '': '<96>',
      \ '': '<97>',
      \ '': '<98>',
      \ '': '<99>',
      \ '': '<9a>',
      \ '': '<9b>',
      \ '': '<9c>',
      \ '': '<9d>',
      \ '': '<9e>',
      \ '': '<9f>',
      \}
