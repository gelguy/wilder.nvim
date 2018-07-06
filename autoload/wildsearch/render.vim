scriptencoding utf-8

let s:hl_index = 0
let s:hl_map = {}

let s:opts = {
      \ 'hl': 'StatusLine',
      \ 'selected_hl': 'WildMenu',
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
    return wildsearch#render#make_page_from_start(a:ctx, a:candidates, l:selected)
  endif

  if l:direction < 0
    return wildsearch#render#make_page_from_end(a:ctx, a:candidates, l:selected)
  endif

  return wildsearch#render#make_page_from_start(a:ctx, a:candidates, l:selected)
endfunction

function! wildsearch#render#make_page_from_start(ctx, candidates, start)
  let l:space = a:ctx.space
  let l:separator = s:opts.separator

  let l:start = a:start
  let l:end = l:start

  let l:width = strdisplaywidth(wildsearch#render#to_printable(a:candidates[l:start]))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(wildsearch#render#to_printable(l:separator))

  while l:end + 1 < len(a:candidates) &&
        \ l:space > strdisplaywidth(wildsearch#render#to_printable(a:candidates[l:end + 1])) + l:separator_width
    let l:space -= strdisplaywidth(wildsearch#render#to_printable(a:candidates[l:end + 1])) + l:separator_width

    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! wildsearch#render#make_page_from_end(ctx, candidates, end)
  let l:space = a:ctx.space
  let l:separator = wildsearch#render#to_printable(s:opts.separator)

  let l:end = a:end
  let l:start = l:end

  let l:width = strdisplaywidth(wildsearch#render#to_printable(a:candidates[l:start]))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(l:separator)

  while l:start - 1 >= 0 &&
        \ l:space > strdisplaywidth(wildsearch#render#to_printable(a:candidates[l:start - 1])) + l:separator_width
    let l:space -= strdisplaywidth(wildsearch#render#to_printable(a:candidates[l:start - 1])) + l:separator_width

    let l:start -= 1
  endwhile

  " moving from page [5,10] ends in [0,4]
  " but there might be leftover space, so we increase l:end to fill up the
  " space e.g. to [0,6]
  while l:end +1 < len(a:candidates) &&
        \ l:space > strdisplaywidth(wildsearch#render#to_printable(a:candidates[l:end + 1])) + l:separator_width
    let l:space -= strdisplaywidth(wildsearch#render#to_printable(a:candidates[l:end + 1])) + l:separator_width

    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! wildsearch#render#need_redraw(ctx, x)
  for l:Component in s:left + s:right
    if type(l:Component) == v:t_dict && has_key(l:Component, 'need_redraw')
      if l:Component.need_redraw(a:ctx, a:x)
        return 1
      endif
    endif
  endfor

  return 0
endfunction

function! wildsearch#render#draw(ctx, candidates)
  let l:res = ''

  let l:res .= wildsearch#render#draw_components(s:left, a:ctx, a:candidates)
  let l:res .= wildsearch#render#draw_candidates(a:ctx, a:candidates)
  let l:res .= wildsearch#render#draw_components(s:right, a:ctx, a:candidates)

  return l:res
endfunction

function! wildsearch#render#draw_candidates(ctx, candidates)
  let l:selected = a:ctx.selected
  let l:space = a:ctx.space
  let l:page = a:ctx.page
  let l:separator = wildsearch#render#to_printable(s:opts.separator)

  if l:page == [-1, -1]
    return '%#' . s:opts.hl . '#' . repeat(' ', l:space)
  endif

  let l:start = l:page[0]
  let l:end = l:page[1]

  " only 1 candidate, possible that it exceeds l:space
  if l:start == l:end
    let l:candidate = wildsearch#render#to_printable(a:candidates[l:start])

    if len(l:candidate) > l:space
      let l:ellipsis = wildsearch#render#to_printable(s:opts.ellipsis)
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

  let g:_wildsearch_candidates = map(copy(a:candidates[l:start : l:end]), {_, x -> wildsearch#render#to_printable(x)})

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

    if type(l:Component.f) == v:t_func
      let l:res .= l:Component.f(a:ctx, a:candidates)
    else
      let l:res .= l:Component.f
    endif
  endfor

  return l:res
endfunction

function! wildsearch#render#space_used(ctx, candidates)
  if !exists('s:left') && !exists('s:right')
    call wildsearch#render#set_components(wildsearch#render#default())
  endif

  let l:len = 0

  for l:Component in s:left + s:right
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
      if type(l:Component.f) == v:t_func
        let l:res = l:Component.f(a:ctx, a:candidates)
      else
        let l:res = l:Component.f
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

function! wildsearch#render#exe_hl()
  for l:hl_name in keys(s:hl_map)
    exe s:hl_map[l:hl_name]
  endfor
endfunction

function! wildsearch#render#make_hl(args)
  let l:ctermfg = a:args[0][0]
  let l:ctermbg = a:args[0][1]
  let l:guifg = a:args[1][0]
  let l:guibg = a:args[1][1]

  let l:hl_name = 'Wildsearch_' . s:hl_index
  let s:hl_index += 1

  let l:cmd = 'hi ' . l:hl_name . ' '

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

  exe l:cmd

  let s:hl_map[l:hl_name] = l:cmd
  return l:hl_name
endfunction

function! wildsearch#render#get_background_colors(group, ) abort
  redir => l:highlight
  silent execute 'silent highlight ' . a:group
  redir END

  let l:link_matches = matchlist(l:highlight, 'links to \(\S\+\)')
  if len(l:link_matches) > 0 " follow the link
    return wildsearch#render#get_background_colors(l:link_matches[1])
  endif

  if !empty(matchlist(l:highlight, 'cterm=\S\*reverse\S\*'))
    let l:ctermbg = wildsearch#render#match_highlight(l:highlight, 'ctermfg=\([0-9A-Za-z]\+\)')
  else
    let l:ctermbg = wildsearch#render#match_highlight(l:highlight, 'ctermbg=\([0-9A-Za-z]\+\)')
  endif

  if !empty(matchlist(l:highlight, 'gui=\S*reverse\S*'))
    let l:guibg = wildsearch#render#match_highlight(l:highlight, 'guifg=\([#0-9A-Za-z]\+\)')
  else
    let l:guibg = wildsearch#render#match_highlight(l:highlight, 'guibg=\([#0-9A-Za-z]\+\)')
  endif

  return [l:ctermbg, l:guibg]
endfunction

function! wildsearch#render#match_highlight(highlight, pattern) abort
  let l:matches = matchlist(a:highlight, a:pattern)
  if len(l:matches) == 0
    return 'NONE'
  endif
  return l:matches[1]
endfunction

function! wildsearch#render#default()
  let l:search_hl = wildsearch#render#make_hl([[0, 0], ['#fdf6e3', '#b58900', 'bold']])
  return {
        \ 'left': [wildsearch#previous_arrow()],
        \ 'right': [wildsearch#next_arrow()],
        \ }
        " \ 'left': [wildsearch#string(' SEARCH ', l:search_hl), wildsearch#separator('', l:search_hl, 'StatusLine'), ' '],
endfunction

function! wildsearch#render#to_printable(x)
  let l:res = ''

  let l:len = strchars(a:x)
  let l:i = 0
  while l:i < l:len
    let l:char = strcharpart(a:x, l:i, 1)
    if has_key(s:high_control_characters, l:char)
      let l:char = s:high_control_characters[l:char]
    elseif match(l:char, '[\x00-\x1F]') >= 0
      let l:char = strtrans(l:char)
    endif

    let l:res .= l:char
    let l:i += 1
  endwhile

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
