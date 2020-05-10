function! wilder#render#renderer#prepare_state(args) abort
  let l:highlights = copy(get(a:args, 'highlights', {}))
  let l:state = {
        \ 'highlights': extend(l:highlights, {
        \   'default': get(a:args, 'hl', 'StatusLine'),
        \   'selected': get(a:args, 'selected_hl', 'WildMenu'),
        \   'error': get(a:args, 'error_hl', 'WildMenu'),
        \ }, 'keep'),
        \ 'separator': wilder#render#to_printable(get(a:args, 'separator', '  ')),
        \ 'ellipsis': wilder#render#to_printable(get(a:args, 'ellipsis', '...')),
        \ 'page': [-1, -1],
        \ 'buf': -1,
        \ 'win': -1,
        \ 'columns': -1,
        \ 'cmdheight': -1,
        \ }

  if !has_key(a:args, 'left') && !has_key(a:args, 'right')
    let l:state.left = [wilder#previous_arrow()]
    let l:state.right = [wilder#next_arrow()]
  else
    let l:state.left = get(a:args, 'left', [])
    let l:state.right = get(a:args, 'right', [])
  endif

  if !has_key(l:state.highlights, 'separator')
    let l:state.highlights.separator =
          \ get(a:args, 'separator_hl', l:state.highlights['default'])
  endif

  if !has_key(l:state.highlights, 'accent')
    let l:state.highlights.accent =
          \ wilder#hl_with_attr('WilderAccent',
          \   l:state.highlights['default'], 'underline', 'bold')
  endif

  if !has_key(l:state.highlights, 'selected_accent')
    let l:state.highlights.selected_accent =
          \ wilder#hl_with_attr('WilderSelectedAccent', l:state.highlights['selected'],
          \   'underline', 'bold')
  endif

  if has_key(a:args, 'apply_accents')
    let l:Apply_accents = a:args['apply_accents']
    if type(l:Apply_accents) isnot v:t_list
      let l:state.apply_accents = [l:Apply_accents]
    else
      let l:state.apply_accents = l:Apply_accents
    endif
  else
      let l:state.apply_accents = []
  endif

  return l:state
endfunction

function! wilder#render#renderer#make_hl_chunks(state, width, ctx, result) abort
  if a:ctx.clear_previous
    let a:state.page = [-1, -1]
  endif

  let l:space_used = wilder#render#component_len(
        \ a:state.left,
        \ a:ctx,
        \ a:result)

  let l:space_used += wilder#render#component_len(
        \ a:state.right,
        \ a:ctx,
        \ a:result)

  let a:ctx.space = a:width - l:space_used
  let a:ctx.page = a:state.page
  let a:ctx.separator = a:state.separator
  let a:ctx.ellipsis = a:state.ellipsis

  let l:page = wilder#render#make_page(a:ctx, a:result)
  let a:ctx.page = l:page
  let a:state.page = l:page

  let a:ctx.highlights = a:state.highlights

  return wilder#render#make_hl_chunks(a:state.left, a:state.right, a:ctx, a:result,
        \ get(a:state, 'apply_accents', []))
endfunction
