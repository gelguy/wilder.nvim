function! wilder#render#renderer#wildmenu_theme#airline_theme(opts) abort
  let l:hls = [
        \ 'airline_c',
        \ 'WildMenu',
        \ 'airline_a',
        \ 'airline_z',
        \ ]
  return s:theme(a:opts, 'Airline', l:hls)
endfunction

function! wilder#render#renderer#wildmenu_theme#lightline_theme(opts) abort
  let l:hls = [
        \ 'LightlineMiddle_active',
        \ 'WildMenu',
        \ 'LightlineLeft_active_0',
        \ 'LightlineRight_active_0',
        \ ]
  return s:theme(a:opts, 'Lightline', l:hls)
endfunction

" {hls} is in the form [default_hl, selected_hl, accent_hl, selected_accent_hl]
function! s:theme(opts, namespace, hls) abort
  if !has_key(a:opts, 'highlights')
    let l:highlights = {}
    let a:opts['highlights'] = l:highlights
  else
    let l:highlights = a:opts['highlights']
  endif

  if !has_key(l:highlights, 'default')
    let l:highlights['default'] = a:hls[0]
  endif
  if !has_key(l:highlights, 'selected')
    let l:highlights['selected'] = a:hls[1]
  endif
  if !has_key(l:highlights, 'accent')
    let l:highlights['accent'] = wilder#hl_with_attr(
          \ 'Wilder' . a:namespace . 'ThemeSelected',
          \ l:highlights['default'], 'underline', 'bold')
  endif
  if !has_key(l:highlights, 'selected_accent')
    let l:highlights['selected_accent'] = wilder#hl_with_attr(
          \ 'Wilder' . a:namespace . 'ThemeAccentSelected',
          \ l:highlights['selected'], 'underline', 'bold')
  endif
  if !has_key(l:highlights, 'mode')
    let l:highlights['mode'] = a:hls[2]
  endif
  if !has_key(l:highlights, 'index')
    let l:highlights['index'] = a:hls[3]
  endif

  if a:namespace ==# 'Airline'
    let l:use_powerline_symbols = get(
          \ a:opts, 'use_powerline_symbols',
          \ get(g:, 'airline_powerline_fonts', 0))

    if l:use_powerline_symbols
      let l:powerline_symbols = get(a:opts, 'powerline_symbols', ['', ''])
    endif
  else
    let l:lightline = get(g:, 'lightline', {})

    let l:use_powerline_symbols = get(
          \ a:opts, 'use_powerline_symbols',
          \ has_key(l:lightline, 'separator'))

    if l:use_powerline_symbols
      if has_key(l:lightline, 'separator')
        let l:lightline_separators = get(l:lightline, 'separator')
        let l:powerline_symbols = [
              \ l:lightline_separators.left, l:lightline_separators.right]
      else
        let l:powerline_symbols = get(a:opts, 'powerline_symbols', ['', ''])
      endif
    endif
  endif


  let l:theme = {
        \ 'left': [
        \   {'value': [
        \     wilder#condition(
        \       {-> getcmdtype() ==# ':'},
        \       ' COMMAND ',
        \       ' SEARCH ',
        \     ),
        \     wilder#condition(
        \       {ctx, x -> has_key(ctx, 'error')},
        \       '!',
        \       wilder#spinner({
        \         'frames': '-\|/',
        \         'done': '·',
        \       }),
        \     ), ' '],
        \   'hl': l:highlights['mode']
        \   },
        \   l:use_powerline_symbols ? 
        \     wilder#powerline_separator(
        \       l:powerline_symbols[0], l:highlights['mode'],
        \       l:highlights['default'], 'left') : '',
        \   ' ',
        \ ],
        \ 'right': [
        \    ' ',
        \   l:use_powerline_symbols ? 
        \     wilder#powerline_separator(
        \       l:powerline_symbols[1], l:highlights['index'],
        \       l:highlights['default'], 'right') : '',
        \    wilder#index({'hl': l:highlights['index']}),
        \ ],
        \ }

  return extend(l:theme, a:opts)
endfunction
