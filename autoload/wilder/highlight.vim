let s:hl_list = []

function! wilder#highlight#init_hl() abort
  for [l:name, l:x, l:xs] in s:hl_list
    call s:make_hl(l:name, l:x, l:xs)
  endfor
endfunction

function! wilder#highlight#make_hl(name, x, xs) abort
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
    let l:x = wilder#highlight#get_hl(a:x)
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

function! wilder#highlight#get_hl(group) abort
  if has('nvim')
    return wilder#highlight#get_hl_nvim(a:group)
  else
    return wilder#highlight#get_hl_vim(a:group)
  endif
endfunction

function! wilder#highlight#get_hl_nvim(group) abort
  try
    let l:cterm_hl = nvim_get_hl_by_name(a:group, 0)
    let l:gui_hl = nvim_get_hl_by_name(a:group, 1)

    return [{}, l:cterm_hl, l:gui_hl]
  catch
    return [{}, {}, {}]
  endtry
endfunction

function! wilder#highlight#get_hl_vim(group) abort
  try
    let l:highlight = execute('silent highlight ' . a:group)

    let l:link_matches = matchlist(l:highlight, 'links to \(\S\+\)')
     " follow the link
    if len(l:link_matches) > 0
      return wilder#highlight#get_hl_vim(l:link_matches[1])
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
