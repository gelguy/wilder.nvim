function! Shell(ctx, x)
  let l:args = {
        \ 'ctx': a:ctx,
        \ 'x': a:x,
        \ 'res': [],
        \ 'errors': [],
        \ 'on_stdout': function('s:on_event'),
        \ 'on_stderr': function('s:on_event'),
        \ 'on_exit': function('s:on_event'),
        \ }

  let l:job = jobstart(a:x, l:args)
  let l:args.job = l:job

  return v:true
endfunction

function! s:on_event(job_id, data, event) dict
  if a:event ==# 'exit'
    if len(l:self.errors) > 0
        let l:self.ctx.error_message = join(l:self.errors, ' ')
        call wildsearch#pipeline#do(l:self.ctx, v:false)
      return
    endif

    call wildsearch#pipeline#do(l:self.ctx, l:self.res)
    return
  endif

  if a:event ==# 'stderr'
    let l:self.errors += filter(copy(a:data), {_, d -> len(d) > 0})
    return
  endif

  let l:self.res += filter(copy(a:data), {_, d -> len(d) > 0})
endfunction

" call wildsearch#main#init()
" set wildcharm=<Tab>

" cmap <expr> <Tab> wildsearch#main#active() ? wildsearch#main#step(1) : "<Tab>"
" cmap <expr> <S-Tab> wildsearch#main#active() ? wildsearch#main#step(-1) : "<S-Tab>"

" call wildsearch#main#set_option('separator', ' · ')

" call wildsearch#pipeline#set_pipeline([
        " \ wildsearch#check({_, x -> len(x) > 1}),
        " \ wildsearch#python_fuzzy_match(),
        " \ {ctx, x -> '\b' . x},
        " \ wildsearch#python_search(),
        " \ wildsearch#python_fuzzy_sort(),
        " \ ])

" let s:search_hl = wildsearch#render#make_hl([[0, 0], ['#fdf6e3', '#b58900', 'bold']])
" let s:index_hl = wildsearch#render#make_hl([[0, 0], ['#eee8d5', '#657b83']])
" call wildsearch#render#set_components({
      " \ 'left': [
      " \    wildsearch#string(' SEARCH ', s:search_hl),
      " \    wildsearch#separator('', s:search_hl, 'StatusLine'), ' ',
      " \ ],
      " \ 'right': [
      " \    ' ', wildsearch#separator('', s:index_hl, 'StatusLine'),
      " \    wildsearch#index({'hl': s:index_hl}),
      " \ ],
      " \ })
