scriptencoding utf-8

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
