func wildsearch#getcompletion#parse(cmdline) abort
  if has_key(s:cache, a:cmdline)
    let l:ctx = s:cache[a:cmdline]

    let l:index = index(s:cache_mru, a:cmdline)
    call remove(s:cache_mru, l:index)
    call add(s:cache_mru, a:cmdline)
  else
    let l:ctx = {'cmdline': a:cmdline, 'pos': 0, 'cmd': ''}
    call wildsearch#getcompletion#main#do(l:ctx)

    let s:cache[a:cmdline] = l:ctx
    call add(s:cache_mru, a:cmdline)

    if len(s:cache_mru) > 100
      let l:removed = remove(s:cache_mru, 0)
      unlet s:cache[l:removed]
    endif
  endif

  return l:ctx
endfunc

let s:cache = {}
let s:cache_mru = []

function! s:check_cache() abort
endfunction

function! wildsearch#getcompletion#has_file_args(cmd)
  return wildsearch#getcompletion#main#has_file_args(a:cmd)
endfunction

func wildsearch#getcompletion#replace(ctx, cmdline, x) abort
  let l:result = wildsearch#getcompletion#parse(a:cmdline)

  if l:result.pos == 0
    return a:x
  endif

  if match(l:result.cmd, 'menu$') != -1
    return l:result.cmdline[: l:result.pos - 1] . a:x
  endif

  return l:result.cmdline[: l:result.pos - 1] . a:x
endfunction

func wildsearch#getcompletion#or(...) abort
  let l:result = 0

  for l:arg in a:000
    let l:result = or(l:result, l:arg)
  endfor

  return l:result
endfunc

func wildsearch#getcompletion#is_whitespace(char)
  let l:nr = char2nr(a:char)
  return a:char ==# ' ' || l:nr >= 9 && l:nr <= 13
endfunc

function! wildsearch#getcompletion#skip_whitespace(ctx) abort
  if empty(a:ctx.cmdline[a:ctx.pos])
    return 0
  endif

  while wildsearch#getcompletion#is_whitespace(a:ctx.cmdline[a:ctx.pos])
    let a:ctx.pos += 1

    if empty(a:ctx.cmdline[a:ctx.pos])
      return 0
    endif
  endwhile

  return 1
endfunction

function! wildsearch#getcompletion#skip_nonwhitespace(ctx) abort
  if empty(a:ctx.cmdline[a:ctx.pos])
    return 0
  endif

  while !wildsearch#getcompletion#is_whitespace(a:ctx.cmdline[a:ctx.pos])
    let a:ctx.pos += 1

    if empty(a:ctx.cmdline[a:ctx.pos])
      return 0
    endif
  endwhile

  return 1
endfunction
