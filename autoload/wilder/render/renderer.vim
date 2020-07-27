let s:open_win_num_args = 3
try
  let l:win = nvim_open_win(0, 0, {})
catch 'Not enough arguments'
  let s:open_win_num_args = 5
catch
endtry

function! wilder#render#renderer#open_win(buf, row, col, height, width) abort
  if s:open_win_num_args == 5
    let l:win = nvim_open_win(a:buf, 0, a:width, a:height, {
          \ 'relative': 'editor',
          \ 'row': a:row,
          \ 'col': a:col,
          \ 'focusable': 0,
          \ })

    call nvim_win_set_option(l:win, 'list', v:false)
    call nvim_win_set_option(l:win, 'number', v:false)
    call nvim_win_set_option(l:win, 'relativenumber', v:false)
    call nvim_win_set_option(l:win, 'spell', v:false)
  else
    let l:win = nvim_open_win(a:buf, 0, {
          \ 'relative': 'editor',
          \ 'height': a:height,
          \ 'width': a:width,
          \ 'row': a:row,
          \ 'col': a:col,
          \ 'focusable': 0,
          \ 'style': 'minimal',
          \ })
  endif

  call nvim_win_set_option(l:win, 'winhighlight', 'Normal:Normal,Search:None,IncSearch:None')
  " call nvim_win_set_option(l:win, 'wrap', v:false)

  return l:win
endfunction

function! wilder#render#renderer#draw_x(cache, ctx, result, i) abort
  let l:use_cache = a:ctx.selected == a:i
  if l:use_cache && has_key(a:cache, a:i)
    return a:cache[a:i]
  endif

  let l:x = wilder#render#draw_x(a:ctx, a:result, a:i)

  if l:use_cache
    let a:cache[a:i] = l:x
  endif

  return l:x
endfunction

function! wilder#render#renderer#cache_apply_highlights(
      \ apply_highlights_cache, apply_highlights, ctx, xs, data) abort
  if empty(a:apply_highlights)
    return
  endif

  for l:x in a:xs
    if !has_key(a:apply_highlights_cache, l:x)
      let l:x_highlight = s:apply_highlights(a:apply_highlights, a:data, l:x)

      if l:x_highlight isnot 0
        let a:apply_highlights_cache[l:x] = l:x_highlight
      endif
    endif
  endfor
endfunction

function! s:apply_highlights(apply_highlights, data, x)
  for l:Apply_highlights in a:apply_highlights
    let l:spans = l:Apply_highlights({}, a:data, a:x)
    if l:spans isnot 0
      return l:spans
    endif
  endfor

  return 0
endfunction
