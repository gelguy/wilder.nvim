scriptencoding utf-8

let s:hl_map = {}
let s:has_strtrans_issue = strdisplaywidth('') != strdisplaywidth(strtrans(''))

let s:opts = wilder#options#get()

function! wilder#render#draw(left, right, ctx, xs) abort
  try
    let l:chunks = []
    let l:chunks += s:draw_components(a:left, s:opts.hl, a:ctx, a:xs)

    if has_key(a:ctx, 'error')
      let l:chunks += s:draw_error(a:ctx, a:ctx.error)
    else
      let l:chunks += s:draw_xs(a:ctx, a:xs)
    endif

    let l:chunks += s:draw_components(a:right, s:opts.hl, a:ctx, a:xs)
    let l:chunks = s:normalise(s:opts.hl, l:chunks)

    if s:opts.renderer ==# 'float'
      call wilder#render#float#draw(l:chunks)
    else
      call wilder#render#statusline#draw(l:chunks)
    endif
  catch
    echohl ErrorMsg
    echomsg 'wilder: ' . v:exception
    echohl Normal
  endtry
endfunction

function! wilder#render#get_components(...) abort
  if !has_key(s:opts, 'render_components')
    let s:opts.render_components = {
          \ 'left': [wilder#previous_arrow()],
          \ 'right': [wilder#next_arrow()]
          \ }
  endif

  if a:0 == 0
    return get(s:opts.render_components, 'left', []) +
          \ get(s:opts.render_components, 'right', [])
  endif

  return get(s:opts.render_components, a:1, [])
endfunction

function! s:component_len(Component, ctx, xs) abort
  if type(a:Component) is v:t_string
    return strdisplaywidth(wilder#render#to_printable(a:Component))
  endif

  if type(a:Component) is v:t_dict
    if has_key(a:Component, 'len')
      if type(a:Component.len) is v:t_func
        return a:Component.len(a:ctx, a:xs)
      else
        return a:Component.len
      endif
    endif

    if type(a:Component.value) is v:t_func
      let l:Value = a:Component.value(a:ctx, a:xs)
    else
      let l:Value = a:Component.value
    endif

    return s:component_len(l:Value, a:ctx, a:xs)
  endif

  if type(a:Component) is v:t_func
    let l:Value = a:Component(a:ctx, a:xs)

    return s:component_len(l:Value, a:ctx, a:xs)
  endif

  " v:t_list
  let l:len = 0

  for l:Elem in a:Component
    let l:len += s:component_len(l:Elem, a:ctx, a:xs)
  endfor

  return l:len
endfunction

function! wilder#render#components_len(components, ctx, xs) abort
  let l:len = 0

  for l:Component in a:components
    let l:len += s:component_len(l:Component, a:ctx, a:xs)
  endfor

  return l:len
endfunction

function! wilder#render#init() abort
  " create highlight before and after components since there might be
  " components which depend on existing highlights
  for l:key in keys(s:hl_map)
    exe s:hl_map[l:key]
  endfor

  call wilder#render#components_pre_hook(wilder#render#get_components(), {})

  for l:key in keys(s:hl_map)
    exe s:hl_map[l:key]
  endfor
endfunction

function! wilder#render#finish() abort
  call wilder#render#components_post_hook(wilder#render#get_components(), {})
endfunction

function! wilder#render#components_pre_hook(components, ctx) abort
  for l:Component in a:components
    if type(l:Component) == v:t_dict && has_key(l:Component, 'pre_hook')
      call l:Component.pre_hook(a:ctx)
    endif
  endfor
endfunction

function! wilder#render#components_post_hook(components, ctx) abort
  for l:Component in a:components
    if type(l:Component) == v:t_dict && has_key(l:Component, 'post_hook')
      call l:Component.post_hook(a:ctx)
    endif
  endfor
endfunction

function! wilder#render#make_page(ctx, xs, page, direction, has_resized) abort
  if empty(a:xs)
    return [-1, -1]
  endif

  let l:selected = a:ctx.selected

  " if selected is within old page
  if a:page != [-1, -1] && l:selected != -1 && l:selected >= a:page[0] && l:selected <= a:page[1]
    " check if page_start to selected still fits within space
    if a:has_resized
      let l:selected = a:ctx.selected
      let l:space = a:ctx.space
      let l:separator = s:opts.separator

      let l:rendered_xs = map(copy(a:xs[a:page[0] : l:selected]), {_, x -> wilder#render#to_printable(x)})
      let l:separator = wilder#render#to_printable(s:opts.separator)

      let l:width = strdisplaywidth(join(l:rendered_xs, l:separator))

      if l:width <= l:space
        return s:make_page_from_start(a:ctx, a:xs, a:page[0])
      endif

      " else make new page
    else
      return a:page
    endif
  endif

  let l:selected = l:selected == -1 ? 0 : l:selected

  if a:page == [-1, -1]
    return s:make_page_from_start(a:ctx, a:xs, l:selected)
  endif

  if a:direction < 0
    return s:make_page_from_end(a:ctx, a:xs, l:selected)
  endif

  return s:make_page_from_start(a:ctx, a:xs, l:selected)
endfunction

function! s:make_page_from_start(ctx, xs, start) abort
  let l:space = a:ctx.space
  let l:separator = s:opts.separator

  let l:start = a:start
  let l:end = l:start

  let l:width = strdisplaywidth(wilder#render#to_printable(a:xs[l:start]))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(wilder#render#to_printable(l:separator))

  while 1
    if l:end + 1 >= len(a:xs)
      break
    endif

    let l:width = strdisplaywidth(wilder#render#to_printable(a:xs[l:end + 1]))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! s:make_page_from_end(ctx, xs, end) abort
  let l:space = a:ctx.space
  let l:separator = wilder#render#to_printable(s:opts.separator)

  let l:end = a:end
  let l:start = l:end

  let l:width = strdisplaywidth(wilder#render#to_printable(a:xs[l:start]))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(l:separator)

  while 1
    if l:start - 1 < 0
      break
    endif

    let l:width = strdisplaywidth(wilder#render#to_printable(a:xs[l:start - 1]))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:start -= 1
  endwhile

  " moving from page [5,10] ends in [0,4]
  " but there might be leftover space, so we increase l:end to fill up the
  " space e.g. to [0,6]
  while 1
    if l:end + 1 >= len(a:xs)
      break
    endif

    let l:width = strdisplaywidth(wilder#render#to_printable(a:xs[l:end + 1]))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! s:normalise(hl, chunks) abort
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
        let l:res += [[l:text, l:hl]]
      endif

      let l:text = l:chunk[0]
      let l:hl = l:chunk_hl
    endif
  endfor

  let l:res += [[l:text, l:hl]]

  return l:res
endfunction

function! s:draw_xs(ctx, xs) abort
  let l:selected = a:ctx.selected
  let l:space = a:ctx.space
  let l:page = a:ctx.page
  let l:separator = wilder#render#to_printable(s:opts.separator)

  if l:page == [-1, -1]
    return [[repeat(' ', l:space), s:opts.hl]]
  endif

  let l:start = l:page[0]
  let l:end = l:page[1]

  " only 1 x, possible that it exceeds l:space
  if l:start == l:end
    let l:x = wilder#render#to_printable(a:xs[l:start])

    if len(l:x) > l:space
      let l:ellipsis = wilder#render#to_printable(s:opts.ellipsis)
      let l:space_minus_ellipsis = l:space - strdisplaywidth(l:ellipsis)

      let l:x = wilder#render#truncate(l:space_minus_ellipsis, l:x)

      let g:_wild_xs = [l:x . l:ellipsis]

      if l:start == l:selected
        let l:hl = s:opts.selected_hl
      else
        let l:hl = s:opts.hl
      endif

      return [[l:x . l:ellipsis, l:hl]]
    endif
  endif

  let l:current = l:start
  let l:res = []
  let l:len = 0

  while l:current <= l:end
    if l:current != l:start
      let l:res += [[l:separator]]
      let l:len += strdisplaywidth(l:separator)
    endif

    if l:current == l:selected
      let l:res += [[wilder#render#to_printable(a:xs[l:current]), s:opts.selected_hl]]
    else
      let l:res += [[wilder#render#to_printable(a:xs[l:current])]]
    endif

    let l:len += strdisplaywidth(a:xs[l:current])
    let l:current += 1
  endwhile

  let l:res += [[repeat(' ', l:space - l:len)]]
  return l:res
endfunction

function! s:draw_error(ctx, error) abort
  let l:space = a:ctx.space
  let l:error = wilder#render#to_printable(a:error)

  if strdisplaywidth(l:error) > a:ctx.space
    let l:ellipsis = wilder#render#to_printable(s:opts.ellipsis)
    let l:space_minus_ellipsis = l:space - strdisplaywidth(l:ellipsis)

    let l:error = wilder#render#truncate(l:space_minus_ellipsis, l:error)

    let l:error = l:error . l:ellipsis
  endif

  return [[l:error, s:opts.error_hl], [repeat(' ', l:space - strdisplaywidth(l:error))]]
endfunction

function! s:draw_components(components, hl, ctx, xs) abort
  let l:hl = a:hl
  let l:res = []

  for l:Component in a:components
    let l:r = s:draw_component(l:Component, l:hl, a:ctx, a:xs)

    if !empty(l:r)
      let l:hl = l:r[-1][1]
    endif

    let l:res += l:r
  endfor

  return l:res
endfunction

function! s:draw_component(Component, hl, ctx, xs) abort
  if type(a:Component) is v:t_string
    return [[wilder#render#to_printable(a:Component), a:hl]]
  endif

  if type(a:Component) is v:t_dict
    if has_key(a:Component, 'hl') && !empty(a:Component.hl)
      let l:hl = a:Component.hl
    else
      let l:hl = a:hl
    endif

    if type(a:Component.value) is v:t_func
      let l:Value = a:Component.value(a:ctx, a:xs)
    else
      let l:Value = a:Component.value
    endif

    return s:draw_component(l:Value, l:hl, a:ctx, a:xs)
  endif

  if type(a:Component) is v:t_func
    let l:Value = a:Component(a:ctx, a:xs)

    return s:draw_component(l:Value, a:hl, a:ctx, a:xs)
  endif

  " v:t_list
  let l:res = []
  let l:hl = a:hl

  for l:Elem in a:Component
    let l:r = s:draw_component(l:Elem, l:hl, a:ctx, a:xs)

    if !empty(l:r)
      let l:hl = l:r[-1][1]
    endif

    let l:res += l:r
  endfor

  return l:res
endfunction

function! wilder#render#make_hl(name, args) abort
  let l:type = type(a:args)
  if l:type == v:t_list
    if type(a:args[0]) == v:t_list
      return s:make_hl_from_list_list(a:name, a:args)
    endif

    return s:make_hl_from_dict_list(a:name, a:args)
  else
    return s:make_hl_from_string(a:name, a:args)
  endif
endfunction

function! s:make_hl_from_string(name, args) abort
  let l:cmd = 'hi! link ' . a:name . ' ' . a:args

  let s:hl_map[a:name] = l:cmd
  return a:name
endfunction

function! s:make_hl_from_dict_list(name, args) abort
  let l:term_hl = s:get_attrs_as_list(a:args[0])

  let l:cterm_hl = [
        \ get(a:args[1], 'foreground', 'NONE'),
        \ get(a:args[1], 'background', 'NONE')
        \ ] + s:get_attrs_as_list(a:args[1])

  let l:gui_hl = [
        \ get(a:args[2], 'foreground', 'NONE'),
        \ get(a:args[2], 'background', 'NONE')
        \ ] + s:get_attrs_as_list(a:args[2])

  return s:make_hl_from_list_list(a:name, [l:term_hl, l:cterm_hl, l:gui_hl])
endfunction

function! s:make_hl_from_list_list(name, args) abort
  let l:term_hl = a:args[0]
  let l:cterm_hl = a:args[1]
  let l:gui_hl = a:args[2]

  let l:cmd = 'hi! ' . a:name . ' '

  if len(l:term_hl) > 2
    let l:cmd .= 'term=' . join(l:term_hl[2:], ',') . ' '
  endif

  if len(l:cterm_hl) > 2
    let l:cmd .= 'cterm=' . join(l:cterm_hl[2:], ',') . ' '
  endif

  if len(l:cterm_hl) >= 1
    if l:cterm_hl[0] >= 0
      let l:cmd .= 'ctermfg=' . l:cterm_hl[0] . ' '
    endif

    if len(l:cterm_hl) >= 2 && l:cterm_hl[1] >= 0
      let l:cmd .= 'ctermbg=' . l:cterm_hl[1] . ' '
    endif
  endif

  if len(l:gui_hl) > 2
    let l:cmd .= 'gui=' . join(l:gui_hl[2:], ',') . ' '
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

  let s:hl_map[a:name] = l:cmd
  return a:name
endfunction

function! s:get_attrs_as_list(attrs) abort
  let l:res = []

  if get(a:attrs, 'bold', 0)
    call add(l:res, 'bold')
  endif
  if get(a:attrs, 'italic', 0)
    call add(l:res, 'italic')
  endif
  if get(a:attrs, 'reverse', 0)
    call add(l:res, 'reverse')
  endif
  if get(a:attrs, 'standout', 0)
    call add(l:res, 'standout')
  endif
  if get(a:attrs, 'underline', 0)
    call add(l:res, 'underline')
  endif
  if get(a:attrs, 'undercurl', 0)
    call add(l:res, 'undercurl')
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
    redir => l:highlight
    silent execute 'silent highlight ' . a:group
    redir END

    let l:link_matches = matchlist(l:highlight, 'links to \(\S\+\)')
    if len(l:link_matches) > 0 " follow the link
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
  let a:attrs.bold = match(a:hl, a:key . '=\S*bold\S*') >= 0
  let a:attrs.italic = match(a:hl, a:key . '=\S*italic\S*') >= 0
  let a:attrs.reverse = match(a:hl, a:key . '=\S*reverse\S*') >= 0
  let a:attrs.standout = match(a:hl, a:key . '=\S*standout\S*') >= 0
  let a:attrs.underline = match(a:hl, a:key . '=\S*underline\S*') >= 0
  let a:attrs.undercurl = match(a:hl, a:key . '=\S*undercurl\S*') >= 0
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

function! wilder#render#truncate(len, str) abort
  " assumes to_printable has been called on str
  let l:chars = split(a:str, '\zs')
  let l:width = strdisplaywidth(a:str)

  if l:width <= a:len
    return a:str
  endif

  let l:index = len(l:chars) - 1
  while l:width > a:len && l:index >= 0
    let l:width -= strdisplaywidth(l:chars[l:index])

    let l:index -= 1
  endwhile

  return join(l:chars[:l:index], '')
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
