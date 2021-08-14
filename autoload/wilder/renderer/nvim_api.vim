let s:index = 0

function! wilder#renderer#nvim_api#() abort
  let l:state = {
        \ 'buf': -1,
        \ 'dummy_buf': -1,
        \ 'win': -1,
        \ 'ns_id': nvim_create_namespace(''),
        \ 'normal_highlight': 'Normal',
        \ 'winblend': 0,
        \ }

  let l:api = {
        \ 'state': l:state,
        \ }

  for l:f in [
        \ 'new',
        \ 'show',
        \ 'hide',
        \ 'move',
        \ 'set_option',
        \ 'set_firstline',
        \ 'delete_all_lines',
        \ 'set_line',
        \ 'add_highlight',
        \ 'clear_all_highlights',
        \ 'need_timer',
        \ ]
    execute 'let l:api.' . l:f . ' = funcref("s:' . l:f . '")'
  endfor

  return l:api
endfunction

function! s:new(opts) dict abort
  if !bufexists(self.state.buf)
    let self.state.buf = s:new_buf()
  endif

  if !bufexists(self.state.dummy_buf)
    let self.state.dummy_buf = s:new_buf()
  endif

  let self.state.normal_highlight = get(a:opts, 'normal_highlight', 'Normal')
  let self.state.winblend = get(a:opts, 'winblend', 0)
endfunction

function! s:new_buf() abort
  let l:buf = nvim_create_buf(v:false, v:true)
  call nvim_buf_set_name(l:buf, '[Wilder Float ' . s:index . ']')
  let s:index += 1

  return l:buf
endfunction

function! s:show() dict abort
  if self.state.win != -1
    return
  endif

  let self.state.win = nvim_open_win(self.state.buf, 0, {
        \ 'relative': 'editor',
        \ 'height': 1,
        \ 'width': 1,
        \ 'row': &lines - 1,
        \ 'col': 0,
        \ 'focusable': 0,
        \ 'style': 'minimal',
        \ })

  call self.set_option('winhighlight',
        \ 'Search:None,IncSearch:None,Normal:' . self.state.normal_highlight)
  call self.set_option('winblend', self.state.winblend)
endfunction

" Floating windows can't be hidden so we close the window.
function! s:hide() dict abort
  if self.state.win == -1
    return
  endif

  if getcmdwintype() ==# ''
    call nvim_win_close(self.state.win, 1)
    call timer_start(0, {-> execute('redraw')})
  else
    " cannot call nvim_win_close() while cmdline-window is open
    " make the window as small as possible and hide it with winblend = 100
    let l:win = self.state.win
    call self.delete_all_lines()
    call self.move(&lines, &columns, 1, 1)
    call self.set_option('winblend', 100)
    execute 'autocmd CmdWinLeave * ++once call timer_start(0, {-> nvim_win_close(' . l:win . ', 0)})'
  endif

  let self.state.win = -1
endfunction

function! s:move(row, col, height, width) dict abort
  call nvim_win_set_config(self.state.win, {
        \ 'relative': 'editor',
        \ 'row': a:row,
        \ 'col': a:col,
        \ 'height': a:height,
        \ 'width': a:width,
        \ })
endfunction

function! s:set_firstline(line) dict abort
  call nvim_win_set_cursor(self.state.win, [a:line, 0])
endfunction

function! s:set_option(option, value) dict abort
  call nvim_win_set_option(self.state.win, a:option, a:value)
endfunction

function! s:delete_all_lines() dict abort
  call nvim_buf_set_lines(self.state.buf, 0, -1, v:true, [])
endfunction

function! s:set_line(line, str) dict abort
  call nvim_buf_set_lines(self.state.buf, a:line, a:line, v:true, [a:str])
endfunction

function! s:add_highlight(hl, line, col_start, col_end) dict abort
  call nvim_buf_add_highlight(self.state.buf, self.state.ns_id, a:hl, a:line, a:col_start, a:col_end)
endfunction

function! s:clear_all_highlights() dict abort
  if !bufexists(self.state.buf)
    return
  endif

  call nvim_buf_clear_namespace(self.state.buf, self.state.ns_id, 0, -1)
endfunction

function! s:need_timer() dict abort
  try
    call nvim_buf_set_lines(self.state.dummy_buf, 0, -1, v:true, [])
  catch
    return 1
  endtry

  return 0
endfunction
