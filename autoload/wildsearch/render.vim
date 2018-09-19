scriptencoding utf-8

let s:hl_map = {}
let s:has_strtrans_issue = strdisplaywidth('') != strdisplaywidth(strtrans(''))

let s:opts = {
      \ 'hl': 'StatusLine',
      \ 'selected_hl': 'WildMenu',
      \ 'error_hl': 'StatusLine',
      \ 'separator': ' ',
      \ 'ellipsis': '...',
      \ }

function! wildsearch#render#set_option(key, value) abort
  let s:opts[a:key] = a:value
endfunction

function! wildsearch#render#set_options(opts) abort
  let s:opts = extend(s:opts, a:opts)
endfunction

function! wildsearch#render#get_option(key) abort
  return s:opts[a:key]
endfunction

function! wildsearch#render#components_len(components, ctx, xs) abort
  let l:len = 0

  for l:Component in a:components
    if type(l:Component) == v:t_func
      let l:len += strdisplaywidth(l:Component(a:ctx, a:xs))
    elseif type(l:Component) == v:t_string
      let l:len += strdisplaywidth(l:Component)
    elseif has_key(l:Component, 'len')
      if type(l:Component.len) == v:t_func
        let l:len += l:Component.len(a:ctx, a:xs)
      else
        let l:len += l:Component.len
      endif
    else
      if type(l:Component.stl) == v:t_func
        let l:res = l:Component.stl(a:ctx, a:xs)
      else
        let l:res = l:Component.stl
      endif

      let l:len += strdisplaywidth(l:res)
    endif
  endfor

  return l:len
endfunction

function! wildsearch#render#init() abort
  " create highlight before and after components since there might be
  " components which depend on existing highlights
  for l:key in keys(s:hl_map)
    exe s:hl_map[l:key]
  endfor

  call wildsearch#render#components_pre_hook(wildsearch#render#get_components(), {})

  for l:key in keys(s:hl_map)
    exe s:hl_map[l:key]
  endfor
endfunction

function! wildsearch#render#finish() abort
  call wildsearch#render#components_post_hook(wildsearch#render#get_components(), {})
endfunction

function! wildsearch#render#components_pre_hook(components, ctx) abort
  for l:Component in a:components
    if type(l:Component) == v:t_dict && has_key(l:Component, 'pre_hook')
      call l:Component.pre_hook(a:ctx)
    endif
  endfor
endfunction

function! wildsearch#render#components_post_hook(components, ctx) abort
  for l:Component in a:components
    if type(l:Component) == v:t_dict && has_key(l:Component, 'post_hook')
      call l:Component.post_hook(a:ctx)
    endif
  endfor
endfunction

function! wildsearch#render#make_page(ctx, xs, page, direction, has_resized) abort
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

      let l:rendered_xs = map(copy(a:xs[a:page[0] : l:selected]), {_, x -> s:to_printable(x)})
      let l:separator = s:to_printable(s:opts.separator)

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

  let l:width = strdisplaywidth(s:to_printable(a:xs[l:start]))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(s:to_printable(l:separator))

  while 1
    if l:end + 1 >= len(a:xs)
      break
    endif

    let l:width = strdisplaywidth(s:to_printable(a:xs[l:end + 1]))

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
  let l:separator = s:to_printable(s:opts.separator)

  let l:end = a:end
  let l:start = l:end

  let l:width = strdisplaywidth(s:to_printable(a:xs[l:start]))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(l:separator)

  while 1
    if l:start - 1 < 0
      break
    endif

    let l:width = strdisplaywidth(s:to_printable(a:xs[l:start - 1]))

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

    let l:width = strdisplaywidth(s:to_printable(a:xs[l:end + 1]))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! wildsearch#render#components_need_redraw(components, ctx, x) abort
  for l:Component in a:components
    if type(l:Component) == v:t_dict && has_key(l:Component, 'redraw')
      if l:Component.redraw(a:ctx, a:x)
        return 1
      endif
    endif
  endfor

  return 0
endfunction

function! wildsearch#render#draw(left, right, ctx, xs) abort
  let l:res = ''

  let l:res .= wildsearch#render#components_draw(a:left, a:ctx, a:xs)
  let l:res .= s:draw_xs(a:ctx, a:xs)
  let l:res .= wildsearch#render#components_draw(a:right, a:ctx, a:xs)

  return l:res
endfunction

function! wildsearch#render#draw_error(left, right, ctx, error) abort
  let l:res = ''

  let l:res .= wildsearch#render#components_draw(a:left, a:ctx, [])
  let l:res .= s:draw_error(a:ctx, a:error)
  let l:res .= wildsearch#render#components_draw(a:right, a:ctx, [])

  return l:res
endfunction

function! s:draw_xs(ctx, xs) abort
  let s:cmdline = getcmdline()
  let l:selected = a:ctx.selected
  let l:space = a:ctx.space
  let l:page = a:ctx.page
  let l:separator = s:to_printable(s:opts.separator)

  if l:page == [-1, -1]
    return '%#' . s:opts.hl . '#' . repeat(' ', l:space)
  endif

  let l:start = l:page[0]
  let l:end = l:page[1]

  " only 1 x, possible that it exceeds l:space
  if l:start == l:end
    let l:x = s:to_printable(a:xs[l:start])

    if len(l:x) > l:space
      let l:ellipsis = s:to_printable(s:opts.ellipsis)
      let l:space_minus_ellipsis = l:space - strdisplaywidth(l:ellipsis)

      let l:x = s:truncate(l:space_minus_ellipsis, l:x)

      let g:_wildsearch_xs = [l:x . l:ellipsis]

      if l:start == l:selected
        let l:res = '%#' . s:opts.selected_hl . '#'
      else
        let l:res = '%#' . s:opts.hl . '#'
      endif

      let l:res .= '%{g:_wildsearch_xs[0]}'

      return l:res . '%#' . s:opts.hl . '#'
    endif
  endif

  let g:_wildsearch_xs = map(copy(a:xs[l:start : l:end]), {_, x -> s:to_printable(x)})

  let l:current = l:start
  let l:res = '%#' . s:opts.hl . '#'
  let l:len = 0

  while l:current <= l:end
    if l:current != l:start
      let l:res .= l:separator
      let l:len += strdisplaywidth(l:separator)
    endif

    if l:current == l:selected
      let l:res .= '%#' . s:opts.selected_hl .
            \ '#%{g:_wildsearch_xs[' . string(l:current-l:start) . ']}' .
            \ '%#' . s:opts.hl . '#'
    else
      let l:res .= '%{g:_wildsearch_xs[' . string(l:current-l:start) . ']}'
    endif

    let l:len += strdisplaywidth(g:_wildsearch_xs[l:current-l:start])
    let l:current += 1
  endwhile

  return l:res . repeat(' ', l:space - l:len)
endfunction

function! s:draw_error(ctx, error) abort
  let l:space = a:ctx.space
  let l:error = s:to_printable(a:error)

  if strdisplaywidth(l:error) > a:ctx.space
    let l:ellipsis = s:to_printable(s:opts.ellipsis)
    let l:space_minus_ellipsis = l:space - strdisplaywidth(l:ellipsis)

    let l:error = s:truncate(l:space_minus_ellipsis, l:error)

    let g:_wildsearch_error = l:error . l:ellipsis
  else
    let g:_wildsearch_error = l:error
  endif

  let l:res = '%#' . s:opts.error_hl . '#%{g:_wildsearch_error}%#' . s:opts.hl . '#'

  return l:res . repeat(' ', l:space - strdisplaywidth(g:_wildsearch_error))
endfunction

function! wildsearch#render#components_draw(components, ctx, xs) abort
  let l:res = ''

  for l:Component in a:components
    if type(l:Component) == v:t_func
      let l:res .= l:Component(a:ctx, a:xs)
      continue
    elseif type(l:Component) == v:t_string
      let l:res .= l:Component
      continue
    endif

    if has_key(l:Component, 'hl')
      let l:res .= '%#' . l:Component.hl . '#'
    endif

    if type(l:Component.stl) == v:t_func
      let l:res .= l:Component.stl(a:ctx, a:xs)
    else
      let l:res .= l:Component.stl
    endif
  endfor

  return l:res
endfunction

function! wildsearch#render#set_components(args) abort
  let s:left = get(a:args, 'left', [])
  let s:right = get(a:args, 'right', [])
endfunction

function! wildsearch#render#get_components(...) abort
  if !exists('s:left') && !exists('s:right')
    call wildsearch#render#set_components(wildsearch#render#default())
  endif

  if a:0 == 0
    return s:left + s:right
  endif

  return a:1 ==# 'left' ? s:left : s:right
endfunction

function! wildsearch#render#make_hl(name, args) abort
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

function! wildsearch#render#get_colors(group) abort
  if has('nvim')
    return wildsearch#render#get_colors_nvim(a:group)
  else
    return wildsearch#render#get_colors_vim(a:group)
  endif
endfunction

function! wildsearch#render#get_colors_nvim(group) abort
  try
    let l:cterm_hl = nvim_get_hl_by_name(a:group, 0)
    let l:gui_hl = nvim_get_hl_by_name(a:group, 1)

    return [{}, l:cterm_hl, l:gui_hl]
  catch
    return [{}, {}, {}]
  endtry
endfunction

function! wildsearch#render#get_colors_vim(group) abort abort
  try
    redir => l:highlight
    silent execute 'silent highlight ' . a:group
    redir END

    let l:link_matches = matchlist(l:highlight, 'links to \(\S\+\)')
    if len(l:link_matches) > 0 " follow the link
      return wildsearch#render#get_colors_vim(l:link_matches[1])
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

function! wildsearch#render#default() abort
  return {
        \ 'left': [wildsearch#previous_arrow()],
        \ 'right': [wildsearch#next_arrow()],
        \ }
endfunction

function! s:to_printable(x) abort
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

function! s:truncate(len, str) abort
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
