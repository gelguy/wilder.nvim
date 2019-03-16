let s:opts = wilder#options#get()
let s:ns_id = nvim_create_namespace('')

let s:buf = -1
let s:win = -1
let s:columns = -1

function! wilder#render#float#draw(chunks) abort
  if s:buf == -1
    let s:buf = nvim_create_buf(v:false, v:true)
  endif

  if s:win == -1
    let s:win = s:new_win()
    let s:columns = &columns
  elseif s:columns != &columns
    let l:win = s:new_win()
    call nvim_win_close(s:win, 1)
    let s:win = l:win
  endif

  let l:text = ''
  for l:elem in a:chunks
    let l:text .= l:elem[0]
  endfor

  call nvim_buf_set_lines(s:buf, 0, -1, v:true, [l:text])

  let l:start = 0
  for l:elem in a:chunks
    let l:end = l:start + len(l:elem[0])

    let l:hl = get(l:elem, 1, s:opts.hl)
    call nvim_buf_add_highlight(s:buf, s:ns_id, l:hl, 0, l:start, l:end)

    let l:start = l:end
  endfor

  redraw
endfunction

function! s:new_win() abort
  let l:win = nvim_open_win(s:buf, 0, &columns, 1, {
        \ 'relative': 'editor',
        \ 'row': &lines - 2,
        \ 'col': 0,
        \ 'focusable': 0,
        \ })

  call nvim_win_set_option(l:win, 'winhl', 'Normal:Normal,Search:None,IncSearch:None')

  return l:win
endfunction

function! wilder#render#float#close() abort
  if s:buf != -1
    call nvim_buf_clear_namespace(s:buf, s:ns_id, 0, -1)
  endif

  if s:win != -1
    call nvim_win_close(s:win, 1)
    let s:win = -1
  endif
endfunction
