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

function! wildsearch#render#set_option(key, value)
  let s:opts[a:key] = a:value
endfunction

function! wildsearch#render#set_options(opts)
  let s:opts = extend(s:opts, a:opts)
endfunction

function! wildsearch#render#get_option(key)
  return s:opts[a:key]
endfunction

function! wildsearch#render#make_page(ctx, candidates)
  if empty(a:candidates)
    return [-1, -1]
  endif

  let l:direction = a:ctx.direction
  let l:selected = a:ctx.selected
  let l:space = a:ctx.space
  let l:page = a:ctx.page
  let l:separator = s:opts.separator

  if l:page != [-1, -1] && l:selected != -1 && l:selected >= l:page[0] && l:selected <= l:page[1]
    return l:page
  endif

  let l:selected = l:selected == -1 ? 0 : l:selected

  if l:page == [-1, -1]
    return s:make_page_from_start(a:ctx, a:candidates, l:selected)
  endif

  if l:direction < 0
    return s:make_page_from_end(a:ctx, a:candidates, l:selected)
  endif

  return s:make_page_from_start(a:ctx, a:candidates, l:selected)
endfunction

function! s:make_page_from_start(ctx, candidates, start)
  let l:space = a:ctx.space
  let l:separator = s:opts.separator

  let l:start = a:start
  let l:end = l:start

  let l:width = strdisplaywidth(s:to_printable(a:candidates[l:start]))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(s:to_printable(l:separator))

  while 1
    if l:end + 1 >= len(a:candidates)
      break
    endif

    let l:width = strdisplaywidth(s:to_printable(a:candidates[l:end + 1]))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! s:make_page_from_end(ctx, candidates, end)
  let l:space = a:ctx.space
  let l:separator = s:to_printable(s:opts.separator)

  let l:end = a:end
  let l:start = l:end

  let l:width = strdisplaywidth(s:to_printable(a:candidates[l:start]))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(l:separator)

  while 1
    if l:start - 1 < 0
      break
    endif

    let l:width = strdisplaywidth(s:to_printable(a:candidates[l:start - 1]))

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
    if l:end + 1 >= len(a:candidates)
      break
    endif

    let l:width = strdisplaywidth(s:to_printable(a:candidates[l:end + 1]))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! wildsearch#render#need_redraw(components, ctx, x)
  for l:Component in a:components
    if type(l:Component) == v:t_dict && has_key(l:Component, 'redraw')
      if l:Component.redraw(a:ctx, a:x)
        return 1
      endif
    endif
  endfor

  return 0
endfunction

function! wildsearch#render#draw(left, right, ctx, candidates)
  let l:res = ''

  let l:res .= wildsearch#render#draw_components(a:left, a:ctx, a:candidates)
  let l:res .= s:draw_candidates(a:ctx, a:candidates)
  let l:res .= wildsearch#render#draw_components(a:right, a:ctx, a:candidates)

  return l:res
endfunction

function! wildsearch#render#draw_error(left, right, ctx, error)
  let l:res = ''

  let l:res .= wildsearch#render#draw_components(a:left, a:ctx, [])
  let l:res .= s:draw_error(a:ctx, a:error)
  let l:res .= wildsearch#render#draw_components(a:right, a:ctx, [])

  return l:res
endfunction

function! s:draw_candidates(ctx, candidates)
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

  " only 1 candidate, possible that it exceeds l:space
  if l:start == l:end
    let l:candidate = s:to_printable(a:candidates[l:start])

    if len(l:candidate) > l:space
      let l:ellipsis = s:to_printable(s:opts.ellipsis)
      let l:space_minus_ellipsis = l:space - strdisplaywidth(l:ellipsis)

      let g:_wildsearch_candidates = [l:candidate[:l:space_minus_ellipsis - 1] . l:ellipsis]

      if l:start == l:selected
        let l:res = '%#' . s:opts.selected_hl . '#'
      else
        let l:res = '%#' . s:opts.hl . '#'
      endif

      let l:res .= '%{g:_wildsearch_candidates[0]}'

      return l:res
    endif
  endif

  let g:_wildsearch_candidates = map(copy(a:candidates[l:start : l:end]), {_, x -> s:to_printable(x)})

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
            \ '#%{g:_wildsearch_candidates[' . string(l:current-l:start) . ']}' .
            \ '%#' . s:opts.hl . '#'
    else
      let l:res .= '%{g:_wildsearch_candidates[' . string(l:current-l:start) . ']}'
    endif

    let l:len += strdisplaywidth(g:_wildsearch_candidates[l:current-l:start])
    let l:current += 1
  endwhile

  return l:res . repeat(' ', l:space - l:len)
endfunction

function! s:draw_error(ctx, error)
  let l:space = a:ctx.space
  let l:error = s:to_printable(a:error)

  if strdisplaywidth(l:error) > a:ctx.space
    let l:ellipsis = s:to_printable(s:opts.ellipsis)
    let l:space_minus_ellipsis = l:space - strdisplaywidth(l:ellipsis)

    let g:_wildsearch_error = l:error[:l:space_minus_ellipsis - 1] . l:ellipsis
  else
    let g:_wildsearch_error = l:error
  endif

  let l:res = '%#' . s:opts.error_hl . '#%{g:_wildsearch_error}%#' . s:opts.hl . '#'

  return l:res . repeat(' ', l:space - strdisplaywidth(g:_wildsearch_error))
endfunction

function! wildsearch#render#draw_components(components, ctx, candidates)
  let l:res = ''

  for l:Component in a:components
    if type(l:Component) == v:t_func
      let l:res .= l:Component(a:ctx, a:candidates)
      continue
    elseif type(l:Component) == v:t_string
      let l:res .= l:Component
      continue
    endif

    if has_key(l:Component, 'hl')
      let l:res .= '%#' . l:Component.hl . '#'
    endif

    if type(l:Component.stl) == v:t_func
      let l:res .= l:Component.stl(a:ctx, a:candidates)
    else
      let l:res .= l:Component.stl
    endif
  endfor

  return l:res
endfunction

function! wildsearch#render#len(components, ctx, candidates)
  let l:len = 0

  for l:Component in a:components
    if type(l:Component) == v:t_func
      let l:len += strdisplaywidth(l:Component(a:ctx, a:candidates))
    elseif type(l:Component) == v:t_string
      let l:len += strdisplaywidth(l:Component)
    elseif has_key(l:Component, 'len')
      if type(l:Component.len) == v:t_func
        let l:len += l:Component.len(a:ctx, a:candidates)
      else
        let l:len += l:Component.len
      endif
    else
      if type(l:Component.stl) == v:t_func
        let l:res = l:Component.stl(a:ctx, a:candidates)
      else
        let l:res = l:Component.stl
      endif

      let l:len += strdisplaywidth(l:res)
    endif
  endfor

  return l:len
endfunction

function! wildsearch#render#set_components(args)
  let s:left = a:args.left
  let s:right = a:args.right
endfunction

function! wildsearch#render#get_components(...)
  if !exists('s:left') && !exists('s:right')
    call wildsearch#render#set_components(wildsearch#render#default())
  endif

  if a:0 == 0
    return s:left + s:right
  endif

  return a:1 ==# 'left' ? s:left : s:right
endfunction

function! wildsearch#render#init()
  " exe before and after components since there might be components which
  " depend on existing highlights
  for l:key in keys(s:hl_map)
    exe s:hl_map[l:key]
  endfor

  call wildsearch#render#init_components(wildsearch#render#get_components(), {})

  for l:key in keys(s:hl_map)
    exe s:hl_map[l:key]
  endfor
endfunction

function! wildsearch#render#init_components(components, ctx)
  for l:Component in a:components
    if type(l:Component) == v:t_dict && has_key(l:Component, 'init')
      call l:Component.init(a:ctx)
    endif
  endfor
endfunction

function! wildsearch#render#make_hl(name, args)
  let l:type = type(a:args)
  if l:type == v:t_list
    return s:make_hl_from_list(a:name, a:args)
  else
    return s:make_hl_from_string(a:name, a:args)
  endif
endfunction

function! s:make_hl_from_string(name, args)
  let l:cmd = 'hi! ' . a:name . ' link ' . a:args

  let s:hl_map[a:name] = l:cmd
  return a:name
endfunction

function! s:make_hl_from_list(name, args)
  let l:ctermfg = a:args[0][0]
  let l:ctermbg = a:args[0][1]
  let l:guifg = a:args[1][0]
  let l:guibg = a:args[1][1]

  let l:cmd = 'hi! ' . a:name . ' '

  if len(a:args[0]) > 2
    let l:cmd .= 'cterm=' . a:args[0][2] . ' '
  endif

  let l:cmd .= 'ctermfg=' . l:ctermfg . ' '
  let l:cmd .= 'ctermbg=' . l:ctermbg . ' '

  if len(a:args[1]) > 2
    let l:cmd .= 'gui=' . a:args[1][2] . ' '
  endif

  let l:cmd .= 'guifg=' . l:guifg . ' '
  let l:cmd .= 'guibg=' . l:guibg

  let s:hl_map[a:name] = l:cmd
  return a:name
endfunction

function! wildsearch#render#get_colors(group)
  if has('nvim')
    return wildsearch#render#get_colors_nvim(a:group)
  else
    return wildsearch#render#get_colors_vim(a:group)
  endif
endfunction

function! wildsearch#render#get_colors_nvim(group)
  try
    let l:cterm_colors = nvim_get_hl_by_name(a:group, 0)
    let l:gui_colors = nvim_get_hl_by_name(a:group, 1)

    if get(l:cterm_colors, 'reverse', 0)
      let l:cterm_res = [get(l:cterm_colors, 'background', 'NONE'), get(l:cterm_colors, 'foreground', 'NONE')]
    else
      let l:cterm_res = [get(l:cterm_colors, 'foreground', 'NONE'), get(l:cterm_colors, 'background', 'NONE')]
    endif

    if has_key(l:gui_colors, 'foreground')
      let l:gui_fg = printf('#%06x', l:gui_colors.foreground)
    else
      let l:gui_fg = 'NONE'
    endif

    if has_key(l:gui_colors, 'background')
      let l:gui_bg = printf('#%06x', l:gui_colors.background)
    else
      let l:gui_bg = 'NONE'
    endif

    if has_key(l:gui_colors, 'reverse')
      let l:gui_res = [l:gui_bg, l:gui_fg]
    else
      let l:gui_res = [l:gui_fg, l:gui_bg]
    endif

    return [l:cterm_res, l:gui_res]
  catch
    return [['NONE', 'NONE'], ['NONE', 'NONE']]
  endtry
endfunction

function! wildsearch#render#get_colors_vim(group) abort
  try
    redir => l:highlight
    silent execute 'silent highlight ' . a:group
    redir END

    let l:link_matches = matchlist(l:highlight, 'links to \(\S\+\)')
    if len(l:link_matches) > 0 " follow the link
      return wildsearch#render#get_background_colors(l:link_matches[1])
    endif

    if !empty(matchlist(l:highlight, 'cterm=\S\*reverse\S\*'))
      let l:ctermfg = s:match_highlight(l:highlight, 'ctermbg=\([0-9A-Za-z]\+\)')
      let l:ctermbg = s:match_highlight(l:highlight, 'ctermfg=\([0-9A-Za-z]\+\)')
    else
      let l:ctermfg = s:match_highlight(l:highlight, 'ctermfg=\([0-9A-Za-z]\+\)')
      let l:ctermbg = s:match_highlight(l:highlight, 'ctermbg=\([0-9A-Za-z]\+\)')
    endif

    if !empty(matchlist(l:highlight, 'gui=\S*reverse\S*'))
      let l:guifg = s:match_highlight(l:highlight, 'guibg=\([#0-9A-Za-z]\+\)')
      let l:guibg = s:match_highlight(l:highlight, 'guifg=\([#0-9A-Za-z]\+\)')
    else
      let l:guifg = s:match_highlight(l:highlight, 'guifg=\([#0-9A-Za-z]\+\)')
      let l:guibg = s:match_highlight(l:highlight, 'guibg=\([#0-9A-Za-z]\+\)')
    endif

    return [[l:ctermfg, l:ctermbg], [l:guifg, l:guibg]]
  catch
    return [['NONE', 'NONE'], ['NONE', 'NONE']]
  endtry
endfunction

function! s:match_highlight(highlight, pattern) abort
  let l:matches = matchlist(a:highlight, a:pattern)
  if len(l:matches) == 0
    return 'NONE'
  endif
  return l:matches[1]
endfunction

function! wildsearch#render#default()
  return {
        \ 'left': [wildsearch#previous_arrow()],
        \ 'right': [wildsearch#next_arrow()],
        \ }
endfunction

function! s:to_printable(x)
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
    elseif l:transformed_width < l:width
      " strtrans returns empty character, fallback to original
      if l:first && strdisplaywidth(' ' . l:char) == strdisplaywidth(l:char)
        " check if first character is combining character
        let l:res .= ' ' . l:char
      else
        let l:res .= l:char
      endif
    else
      " strtrans returns extra characters, fallback to hex representation
      let l:res .= '<' . printf('%02x', char2nr(l:char)) . '>'
    endif

    let l:first = 0
  endfor

  return l:res
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
