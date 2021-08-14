function! wilder#setup#(...)
  let l:config = get(a:, 1, {})

  if get(l:config, 'enable_cmdline_enter', 1)
    call wilder#enable_cmdline_enter()
  endif

  let l:wildcharm = get(l:config, 'wildcharm', &wildchar)
  if l:wildcharm isnot v:false
    execute 'set wildcharm='. &wildchar
  endif

  let l:modes = get(l:config, 'modes', ['/', '?'])
  call wilder#set_option('modes', l:modes)

  for [l:key, l:default_mapping, l:command] in [
        \ ['next_key', '<Tab>', 'wilder#in_context() ? wilder#next() :'],
        \ ['previous_key', '<S-Tab>', 'wilder#in_context() ? wilder#previous() :'],
        \ ['reject_key', '<Up>', 'wilder#can_reject_completion() ? wilder#reject_completion() :'],
        \ ['accept_key', '<Down>', 'wilder#can_accept_completion() ? wilder#accept_completion() :'],
        \ ]
    let l:mapping = get(l:config, l:key, l:default_mapping)
    if l:mapping is v:false
      continue
    endif

    if type(l:mapping) is v:t_list
      let l:fallback_mapping = l:mapping[1]
      let l:mapping = l:mapping[0]
    else
      let l:fallback_mapping = l:mapping
    endif

    if l:key ==# 'accept_key' &&
          \ !get(l:config, 'accept_completion_auto_select', 1)
      let l:command = 'wilder#can_accept_completion() ? wilder#accept_completion(0) :'
    endif

    execute 'cmap <expr>' l:mapping l:command string(l:fallback_mapping)
  endfor

endfunction
