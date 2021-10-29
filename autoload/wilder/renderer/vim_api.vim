let s:index = 0

function! wilder#renderer#vim_api#() abort
  let l:state = {
        \ 'buf': -1,
        \ 'dummy_buf': -1,
        \ 'win': -1,
        \ 'prop_types': {},
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

  if index(popup_list(), self.state.win) == -1
    let l:popup_opts = {
          \ 'line': 1,
          \ 'col': 1,
          \ 'fixed': 1,
          \ 'wrap': 0,
          \ 'scrollbar': 0,
          \ 'cursorline': 0,
          \ 'highlight': get(a:opts, 'normal_highlight', 'Normal'),
          \ }

    let l:zindex = get(a:opts, 'zindex', v:null)
    if a:opts.zindex != v:null
      let l:popup_opts.zindex = l:zindex
    endif

    let self.state.win = popup_create(self.state.buf, l:popup_opts)
    call popup_hide(self.state.win)
  endif
endfunction

function! s:new_buf() abort
  let l:old_shortmess = &shortmess
  set shortmess+=F

  let l:buf = bufadd('[Wilder Popup ' . s:index . ']')
  call bufload(l:buf)

  call setbufvar(l:buf, '&buftype', 'nofile')
  call setbufvar(l:buf, '&bufhidden', 1)
  call setbufvar(l:buf, '&swapfile', 0)
  call setbufvar(l:buf, '&undolevels', -1)

  let &shortmess = l:old_shortmess

  let s:index += 1
  return l:buf
endfunction

function! s:show() dict abort
  call popup_show(self.state.win)
endfunction

" Floating windows can't be hidden so we close the window.
function! s:hide() dict abort
  call popup_hide(self.state.win)
endfunction

function! s:move(row, col, height, width) dict abort
  call popup_move(self.state.win, {
        \ 'line': a:row + 1,
        \ 'col': a:col + 1,
        \ 'minwidth': a:width,
        \ 'maxwidth': a:width,
        \ 'minheight': a:height,
        \ 'maxheight': a:height,
        \ })
endfunction

function! s:set_firstline(line) dict abort
  call popup_setoptions(self.state.win, {
        \ 'firstline': a:line,
        \ })
endfunction

function! s:set_option(option, value) dict abort
  let l:options = {}
  let l:options[a:option] = a:value
  call popup_setoptions(self.state.win, l:options)
endfunction

function! s:delete_all_lines() dict abort
  call deletebufline(self.state.buf, 1, '$')
endfunction

function! s:set_line(line, str) dict abort
  call setbufline(self.state.buf, a:line + 1, a:str)
endfunction

function! s:add_highlight(hl, line, col_start, col_end) dict abort
  if !bufexists(self.state.buf)
    return
  endif

  let l:prop_type = 'WilderProp_' . a:hl

  if !has_key(self.state.prop_types, a:hl)
    call prop_type_add(l:prop_type, {
          \ 'bufnr': self.state.buf,
          \ 'highlight': a:hl,
          \ 'combine': 0,
          \ })

    let self.state.prop_types[a:hl] = 1
  endif

  let l:length = a:col_end - a:col_start

  " Avoid zero-width highlights as it might mess up adjacent highlights.
  if l:length > 0
    call prop_add(a:line + 1, a:col_start + 1, {
          \ 'bufnr': self.state.buf,
          \ 'length': l:length,
          \ 'type': l:prop_type,
          \ })
  endif
endfunction

function! s:clear_all_highlights() dict abort
  if !bufexists(self.state.buf)
    return
  endif

  let l:prop_types = prop_type_list({'bufnr': self.state.buf})
  for l:prop_type in l:prop_types
    call prop_type_delete(l:prop_type, {'bufnr': self.state.buf})
  endfor

  let self.state.prop_types = {}
endfunction

function! s:need_timer() dict abort
  try
    call setbufline(self.state.dummy_buf, 1, '')
  catch
    return 1
  endtry

  return 0
endfunction
