function! wild#cmdline#main#do(ctx) abort
  if empty(a:ctx.cmdline[a:ctx.pos :])
    return
  endif

  if !wild#cmdline#main#skip_whitespace(a:ctx)
    return
  endif

  " check if comment
  if a:ctx.cmdline[a:ctx.pos] ==# '"'
    let a:ctx.pos = len(a:ctx.cmdline)
    return
  endif

  " skip range
  call wild#cmdline#skip_range#do(a:ctx)

  if !wild#cmdline#main#skip_whitespace(a:ctx)
    return
  endif

  if a:ctx.cmdline[a:ctx.pos] ==# '"'
    let a:ctx.pos = len(a:ctx.cmdline)
    return
  endif

  " check if starts with | or :
  " treat as a new command
  if a:ctx.cmdline[a:ctx.pos] ==# '|' || a:ctx.cmdline[a:ctx.pos] ==# ':'
    let a:ctx.pos += 1
    let a:ctx.cmd = ''

    call wild#cmdline#main#do(a:ctx)

    return
  endif

  let l:is_user_cmd = 0

  if a:ctx.cmdline[a:ctx.pos] ==# 'k' && a:ctx.cmdline[a:ctx.pos + 1] !=# 'e'
    let a:ctx.cmd = 'k'
    let a:ctx.pos += 1

    return
  else
    let l:cmd_start = a:ctx.pos

    let l:char = a:ctx.cmdline[a:ctx.pos]

    if l:char >=# 'A' && l:char <=# 'Z'
      " user-defined command can contain digits
      while l:char >=# 'a' && l:char <=# 'z' ||
            \ l:char >=# 'A' && l:char <=# 'Z' ||
            \ l:char >=# '0' && l:char <=# '9'
        let a:ctx.pos += 1
        let l:char = a:ctx.cmdline[a:ctx.pos]
      endwhile

      let a:ctx.cmd = a:ctx.cmdline[l:cmd_start : a:ctx.pos - 1]
      let l:is_user_cmd = 1
    else
      " non-alphabet command
      if stridx('@*!=><&~#', l:char) != -1
        let a:ctx.pos += 1
        let l:char = a:ctx.cmdline[a:ctx.pos]
      else
        " for py3*, only set of default commands with numbers
        " other commands are alphabet only
        if a:ctx.cmdline[a:ctx.pos] ==# 'p' &&
              \ a:ctx.cmdline[a:ctx.pos + 1] ==# 'y' &&
              \ a:ctx.cmdline[a:ctx.pos + 2] ==# '3'
          let a:ctx.pos += 3
          let l:char = a:ctx.cmdline[a:ctx.pos]
        endif

        while l:char >=# 'a' && l:char <=# 'z' ||
              \ l:char >=# 'A' && l:char <=# 'Z'
          let a:ctx.pos += 1
          let l:char = a:ctx.cmdline[a:ctx.pos]
        endwhile
      endif

      " find the command
      if a:ctx.pos > l:cmd_start
        let l:cmd = a:ctx.cmdline[l:cmd_start : a:ctx.pos - 1]
        let l:len = a:ctx.pos - l:cmd_start

        for l:command in s:commands
          if l:cmd ==# l:command.command[: l:len - 1]
            let a:ctx.cmd = l:command.command
            break
          endif
        endfor
      endif
    endif
  endif

  " cursor is touching command and ends in alpha-numeric character
  " complete the command name
  if a:ctx.pos == len(a:ctx.cmdline)
    let l:char = a:ctx.cmdline[a:ctx.pos - 1]

    if l:char >=# 'a' && l:char <=# 'z' ||
          \ l:char >=# 'A' && l:char <=# 'Z' ||
          \ l:char >=# '0' && l:char <=# '9'
      let a:ctx.pos = l:cmd_start
      let a:ctx.cmd = ''
      return
    endif
  endif

  " no matching command found, treat as no arguments
  if empty(a:ctx.cmd)
    " 2 or 3-letter substitute command, takes no arguments
    if a:ctx.cmdline[l:cmd_start] ==# 's' &&
          \ stridx('cgriI', a:ctx.cmdline[l:cmd_start + 1]) != -1
      let a:ctx.cmd = 'substitute'
    endif

    let a:ctx.pos = len(a:ctx.cmdline)
    return
  endif

  let l:force = 0

  " handle !
  if a:ctx.cmdline[a:ctx.pos] ==# '!'
    let a:ctx.pos += 1
    let l:force = 1
  endif

  if !wild#cmdline#main#skip_whitespace(a:ctx)
    return
  endif

  if has_key(s:command_map, a:ctx.cmd)
    let l:flags = s:command_map[a:ctx.cmd].flags
  else
    let l:flags = 0
  endif

  let l:use_filter = 0

  if a:ctx.cmd ==# 'write' || a:ctx.cmd ==# 'update'
    if a:ctx.cmdline[a:ctx.pos] ==# '>'
      let a:ctx.pos += 1

      if a:ctx.cmdline[a:ctx.pos] ==# '>'
        let a:ctx.pos += 1
      endif

      if !wild#cmdline#main#skip_whitespace(a:ctx)
        return
      endif
    endif

    if a:ctx.cmd ==# 'write' && a:ctx.cmdline[a:ctx.pos] ==# '!'
      let a:ctx.pos += 1
      let l:use_filter = 1
    endif
  elseif a:ctx.cmd ==# 'read'
    if a:ctx.cmdline[a:ctx.pos] ==# '!'
      let a:ctx.pos += 1
      let l:use_fitler = 1
    else
      let l:use_filter = l:force
    endif
  elseif a:ctx.cmd ==# '<' || a:ctx.cmd ==# '>'
    while a:ctx.cmdline[a:ctx.pos] ==# a:ctx.cmd
      let a:ctx.pos += 1
    endwhile

    if !wild#cmdline#main#skip_whitespace(a:ctx)
      return
    endif
  endif

  " +command
  if and(l:flags, s:EDITCMD) &&
        \ !l:use_filter && a:ctx.cmdline[a:ctx.pos] ==# '+'
    call wild#cmdline#skip_plus_command#do(a:ctx)
  endif

  if !wild#cmdline#main#skip_whitespace(a:ctx)
    return
  endif

  " look for | for new command and " for comment
  if and(l:flags, s:TRLBAR) && !l:use_filter
    if a:ctx.cmd ==# 'redir' &&
          \ a:ctx.cmdline[a:ctx.pos] ==# '@' &&
          \ a:ctx.cmdline[a:ctx.pos + 1] ==# '"'
      let a:ctx.pos += 2
    endif

    let l:lookahead = a:ctx.pos
    while l:lookahead < len(a:ctx.cmdline)
      if a:ctx.cmdline[l:lookahead] ==# "\<C-V>" || a:ctx.cmdline[l:lookahead] ==# '\'
        let l:lookahead += 1

        if l:lookahead + 1 < len(a:ctx.cmdline)
          let l:lookahead += 1
        else
          return
        endif
      endif

      " remaining part of cmdline is comment, treat as no arguments
      if a:ctx.cmdline[l:lookahead] ==# '"'
        let a:ctx.pos = len(a:ctx.cmdline)

        return
      " start of new command
      elseif a:ctx.cmdline[l:lookahead] ==# '|'
        let a:ctx.pos = l:lookahead + 1
        let a:ctx.cmd = ''

        call wild#cmdline#main#do(a:ctx)

        return
      endif

      " TODO: multibyte
      let l:lookahead += 1
    endwhile
  endif

  " command does not take extra arguments
  if !and(l:flags, s:EXTRA) && !l:is_user_cmd
    " consume whitespace
    if !wild#cmdline#main#skip_whitespace(a:ctx)
      return
    endif

    " and check for | or "
    if a:ctx.cmdline[a:ctx.pos] ==# '|'
      let a:ctx.pos += 1
      let a:ctx.cmd = ''

      call wild#cmdline#main#do(a:ctx)
      return
    else
      " remaining part is either comment or invalid arguments
      " either way, treat as no arguments
      let a:ctx.pos = len(a:ctx.cmdline)
      return
    endif
  endif

  if !wild#cmdline#main#skip_whitespace(a:ctx)
    return
  endif

  " command modifiers
  if a:ctx.cmd ==# 'aboveleft' ||
        \ a:ctx.cmd ==# 'argdo' ||
        \ a:ctx.cmd ==# 'belowright' ||
        \ a:ctx.cmd ==# 'botright' ||
        \ a:ctx.cmd ==# 'browse' ||
        \ a:ctx.cmd ==# 'bufdo' ||
        \ a:ctx.cmd ==# 'cdo' ||
        \ a:ctx.cmd ==# 'cfdo' ||
        \ a:ctx.cmd ==# 'confirm' ||
        \ a:ctx.cmd ==# 'debug' ||
        \ a:ctx.cmd ==# 'folddoclosed' ||
        \ a:ctx.cmd ==# 'folddoopen' ||
        \ a:ctx.cmd ==# 'hide' ||
        \ a:ctx.cmd ==# 'keepalt' ||
        \ a:ctx.cmd ==# 'keepjumps' ||
        \ a:ctx.cmd ==# 'keepmarks' ||
        \ a:ctx.cmd ==# 'keeppatterns' ||
        \ a:ctx.cmd ==# 'ldo' ||
        \ a:ctx.cmd ==# 'leftabove' ||
        \ a:ctx.cmd ==# 'lfdo' ||
        \ a:ctx.cmd ==# 'lockmarks' ||
        \ a:ctx.cmd ==# 'noautocmd' ||
        \ a:ctx.cmd ==# 'noswapfile' ||
        \ a:ctx.cmd ==# 'rightbelow' ||
        \ a:ctx.cmd ==# 'sandbox' ||
        \ a:ctx.cmd ==# 'silent' ||
        \ a:ctx.cmd ==# 'tab' ||
        \ a:ctx.cmd ==# 'tabdo' ||
        \ a:ctx.cmd ==# 'topleft' ||
        \ a:ctx.cmd ==# 'verbose' ||
        \ a:ctx.cmd ==# 'vertical' ||
        \ a:ctx.cmd ==# 'windo'
    let a:ctx.cmd = ''

    call wild#cmdline#main#do(a:ctx)

    return
  endif

  if a:ctx.cmd ==# 'filter'
    call wild#cmdline#filter#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'match'
    call wild#cmdline#match#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'command'
    call wild#cmdline#command#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'global' || a:ctx.cmd ==# 'vglobal'
    call wild#cmdline#global#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# '&' || a:ctx.cmd ==# 'substitute'
    call wild#cmdline#substitute#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'isearch' ||
        \ a:ctx.cmd ==# 'dsearch' ||
        \ a:ctx.cmd ==# 'ilist' ||
        \ a:ctx.cmd ==# 'dlist' ||
        \ a:ctx.cmd ==# 'ijump' ||
        \ a:ctx.cmd ==# 'psearch' ||
        \ a:ctx.cmd ==# 'djump' ||
        \ a:ctx.cmd ==# 'isplit' ||
        \ a:ctx.cmd ==# 'dsplit'
    call wild#cmdline#isearch#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'autocmd' ||
        \ a:ctx.cmd ==# 'doautocmd' ||
        \ a:ctx.cmd ==# 'doautoall'
    call wild#cmdline#autocmd#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'set' ||
        \ a:ctx.cmd ==# 'setglobal' ||
        \ a:ctx.cmd ==# 'setlocal'
    call wild#cmdline#set#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'syntax'
    call wild#cmdline#syntax#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'let' ||
        \ a:ctx.cmd ==# 'if' ||
        \ a:ctx.cmd ==# 'elseif' ||
        \ a:ctx.cmd ==# 'while' ||
        \ a:ctx.cmd ==# 'for' ||
        \ a:ctx.cmd ==# 'echo' ||
        \ a:ctx.cmd ==# 'echon' ||
        \ a:ctx.cmd ==# 'execute' ||
        \ a:ctx.cmd ==# 'echomsg' ||
        \ a:ctx.cmd ==# 'echoerr' ||
        \ a:ctx.cmd ==# 'call' ||
        \ a:ctx.cmd ==# 'return' ||
        \ a:ctx.cmd ==# 'cexpr' ||
        \ a:ctx.cmd ==# 'caddexpr' ||
        \ a:ctx.cmd ==# 'cgetexpr' ||
        \ a:ctx.cmd ==# 'lexpr' ||
        \ a:ctx.cmd ==# 'laddexpr' ||
        \ a:ctx.cmd ==# 'lgetexpr'
    call wild#cmdline#let#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'highlight'
    call wild#cmdline#highlight#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'cscope' ||
        \ a:ctx.cmd ==# 'lcscope' ||
        \ a:ctx.cmd ==# 'scscope'
    call wild#cmdline#cscope#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'sign'
    call wild#cmdline#sign#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'abbreviate' ||
        \ a:ctx.cmd ==# 'unabbreviate' ||
        \ match(a:ctx.cmd, 'map$') != -1 ||
        \ match(a:ctx.cmd, 'abbrev$') != -1
    call wild#cmdline#map#do(a:ctx)
    return
  endif

  if match(a:ctx.cmd, 'menu$') != -1
    call wild#cmdline#menu#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'profile'
    call wild#cmdline#profile#do(a:ctx)
    return
  endif

  " commands which only have 1 argument
  " take the whole cmdline excluding the command as the argument
  if a:ctx.cmd ==# 'help' ||
        \ a:ctx.cmd ==# 'delcommand' ||
        \ a:ctx.cmd ==# 'tag' ||
        \ a:ctx.cmd ==# 'stag' ||
        \ a:ctx.cmd ==# 'ptag' ||
        \ a:ctx.cmd ==# 'ltag' ||
        \ a:ctx.cmd ==# 'tselect' ||
        \ a:ctx.cmd ==# 'stselect' ||
        \ a:ctx.cmd ==# 'ptselect' ||
        \ a:ctx.cmd ==# 'tjump' ||
        \ a:ctx.cmd ==# 'stjump' ||
        \ a:ctx.cmd ==# 'ptjump' ||
        \ a:ctx.cmd ==# 'augroup' ||
        \ a:ctx.cmd ==# 'function' ||
        \ a:ctx.cmd ==# 'delfunction' ||
        \ a:ctx.cmd ==# 'buffer' ||
        \ a:ctx.cmd ==# 'sbuffer' ||
        \ a:ctx.cmd ==# 'checktime' ||
        \ a:ctx.cmd ==# 'checktime' ||
        \ a:ctx.cmd ==# 'mapclear' ||
        \ a:ctx.cmd ==# 'nmapclear' ||
        \ a:ctx.cmd ==# 'vmapclear' ||
        \ a:ctx.cmd ==# 'omapclear' ||
        \ a:ctx.cmd ==# 'imapclear' ||
        \ a:ctx.cmd ==# 'cmapclear' ||
        \ a:ctx.cmd ==# 'lmapclear' ||
        \ a:ctx.cmd ==# 'smapclear' ||
        \ a:ctx.cmd ==# 'xmapclear' ||
        \ a:ctx.cmd ==# 'colorscheme' ||
        \ a:ctx.cmd ==# 'compiler' ||
        \ a:ctx.cmd ==# 'ownsyntax' ||
        \ a:ctx.cmd ==# 'setfiletype' ||
        \ a:ctx.cmd ==# 'packadd' ||
        \ a:ctx.cmd ==# 'checkhealth' ||
        \ a:ctx.cmd ==# 'behave' ||
        \ a:ctx.cmd ==# 'messages' ||
        \ a:ctx.cmd ==# 'history' ||
        \ a:ctx.cmd ==# 'syntime' ||
        \ a:ctx.cmd ==# ''
    return
  endif

  " handle rest of commands including user-defined commands
  " assume arguments are split by whitespace
  " for commands which don't have arguments or have invalid arguments
  " this is ok, since wild#cmdline() will return no results
  let l:arg_start = a:ctx.pos

  while a:ctx.pos < len(a:ctx.cmdline)
    let l:char = a:ctx.cmdline[a:ctx.pos]

    if l:char ==# '\'
      if a:ctx.pos + 1 < len(a:ctx.cmdline)
        let a:ctx.pos += 1
      endif
    elseif wild#cmdline#main#is_whitespace(l:char)
      let l:arg_start = a:ctx.pos + 1

    " special case for files
    " / will be treated as start of new arg
    " $ is not included in the arg if found at the start of arg
    " handle case where there is no whitespace between command and argument
    elseif and(l:flags, s:XFILE)
      if l:char ==# '$' &&
          \ (l:arg_start == a:ctx.pos - 1 || l:arg_start == a:ctx.pos)
        let l:arg_start = a:ctx.pos + 1
      endif
    endif

    let a:ctx.pos += 1
  endwhile

  let a:ctx.pos = l:arg_start
endfunc

function! wild#cmdline#main#has_file_args(cmd) abort
  let l:command = get(s:command_map, a:cmd, {})
  let l:flags = get(l:command, 'flags', 0)
  return and(l:flags, s:XFILE)
endfunction

func wild#cmdline#main#is_whitespace(char)
  let l:nr = char2nr(a:char)
  return a:char ==# ' ' || l:nr >= 9 && l:nr <= 13
endfunc

function! wild#cmdline#main#skip_whitespace(ctx) abort
  if empty(a:ctx.cmdline[a:ctx.pos])
    return 0
  endif

  while wild#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
    let a:ctx.pos += 1

    if empty(a:ctx.cmdline[a:ctx.pos])
      return 0
    endif
  endwhile

  return 1
endfunction

function! wild#cmdline#main#skip_nonwhitespace(ctx) abort
  if empty(a:ctx.cmdline[a:ctx.pos])
    return 0
  endif

  while !wild#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
    let a:ctx.pos += 1

    if empty(a:ctx.cmdline[a:ctx.pos])
      return 0
    endif
  endwhile

  return 1
endfunction

func s:or(...) abort
  let l:result = 0

  for l:arg in a:000
    let l:result = or(l:result, l:arg)
  endfor

  return l:result
endfunc

let s:RANGE      =    0x001
let s:BANG       =    0x002
let s:EXTRA      =    0x004
let s:XFILE      =    0x008
let s:NOSPC      =    0x010
let s:DFLALL     =    0x020
let s:WHOLEFOLD  =    0x040
let s:NEEDARG    =    0x080
let s:TRLBAR     =    0x100
let s:REGSTR     =    0x200
let s:COUNT      =    0x400
let s:NOTRLCOM   =    0x800
let s:ZEROR      =   0x1000
let s:USECTRLV   =   0x2000
let s:NOTADR     =   0x4000
let s:EDITCMD    =   0x8000
let s:BUFNAME    =  0x10000
let s:BUFUNL     =  0x20000
let s:ARGOPT     =  0x40000
let s:SBOXOK     =  0x80000
let s:CMDWIN     = 0x100000
let s:MODIFY     = 0x200000
let s:EXFLAGS    = 0x400000
let s:FILES      = s:or(s:XFILE, s:EXTRA)
let s:WORD1      = s:or(s:EXTRA, s:NOSPC)
let s:FILE1      = s:or(s:FILES, s:NOSPC)

let s:commands = [
      \  {
      \    'command':'append',
      \    'flags':s:or(s:BANG, s:RANGE, s:ZEROR, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'abbreviate',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'abclear',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'aboveleft',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'all',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'amenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'anoremenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'args',
      \    'flags':s:or(s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'argadd',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:ZEROR, s:FILES, s:TRLBAR),
      \  },
      \  {
      \    'command':'argdelete',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:FILES, s:TRLBAR),
      \  },
      \  {
      \    'command':'argdo',
      \    'flags':s:or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'argedit',
      \    'flags':s:or(s:BANG, s:NEEDARG, s:RANGE, s:NOTADR, s:ZEROR, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'argglobal',
      \    'flags':s:or(s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'arglocal',
      \    'flags':s:or(s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'argument',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EXTRA, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'ascii',
      \    'flags':s:or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'autocmd',
      \    'flags':s:or(s:BANG, s:EXTRA, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'augroup',
      \    'flags':s:or(s:BANG, s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'aunmenu',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'buffer',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:BUFNAME, s:BUFUNL, s:COUNT, s:EXTRA, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'bNext',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'ball',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'badd',
      \    'flags':s:or(s:NEEDARG, s:FILE1, s:EDITCMD, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'bdelete',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:BUFNAME, s:COUNT, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'behave',
      \    'flags':s:or(s:NEEDARG, s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'belowright',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'bfirst',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'blast',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'bmodified',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'bnext',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'botright',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'bprevious',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'brewind',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'break',
      \    'flags':s:or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'breakadd',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'breakdel',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'breaklist',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'browse',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:CMDWIN),
      \  },
      \  {
      \    'command':'buffers',
      \    'flags':s:or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'bufdo',
      \    'flags':s:or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'bunload',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:BUFNAME, s:COUNT, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'bwipeout',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:BUFNAME, s:BUFUNL, s:COUNT, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'change',
      \    'flags':s:or(s:BANG, s:WHOLEFOLD, s:RANGE, s:COUNT, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'cNext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cNfile',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cabbrev',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cabclear',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'caddbuffer',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:WORD1, s:TRLBAR),
      \  },
      \  {
      \    'command':'caddexpr',
      \    'flags':s:or(s:NEEDARG, s:WORD1, s:NOTRLCOM, s:TRLBAR),
      \  },
      \  {
      \    'command':'caddfile',
      \    'flags':s:or(s:TRLBAR, s:FILE1),
      \  },
      \  {
      \    'command':'call',
      \    'flags':s:or(s:RANGE, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'catch',
      \    'flags':s:or(s:EXTRA, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'cbuffer',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:WORD1, s:TRLBAR),
      \  },
      \  {
      \    'command':'cbottom',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'cc',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cclose',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'cd',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'cdo',
      \    'flags':s:or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'center',
      \    'flags':s:or(s:TRLBAR, s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'cexpr',
      \    'flags':s:or(s:NEEDARG, s:WORD1, s:NOTRLCOM, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cfile',
      \    'flags':s:or(s:TRLBAR, s:FILE1, s:BANG),
      \  },
      \  {
      \    'command':'cfdo',
      \    'flags':s:or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'cfirst',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cgetfile',
      \    'flags':s:or(s:TRLBAR, s:FILE1),
      \  },
      \  {
      \    'command':'cgetbuffer',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:WORD1, s:TRLBAR),
      \  },
      \  {
      \    'command':'cgetexpr',
      \    'flags':s:or(s:NEEDARG, s:WORD1, s:NOTRLCOM, s:TRLBAR),
      \  },
      \  {
      \    'command':'chdir',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'changes',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'checkhealth',
      \    'flags':s:or(s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'checkpath',
      \    'flags':s:or(s:TRLBAR, s:BANG, s:CMDWIN),
      \  },
      \  {
      \    'command':'checktime',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BUFNAME, s:COUNT, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'chistory',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'clist',
      \    'flags':s:or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'clast',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'close',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'clearjumps',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'cmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cmapclear',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'cmenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cnext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cnewer',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'cnfile',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cnoremap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cnoreabbrev',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cnoremenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'copy',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'colder',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'colorscheme',
      \    'flags':s:or(s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'command',
      \    'flags':s:or(s:EXTRA, s:BANG, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'comclear',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'compiler',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:WORD1, s:CMDWIN),
      \  },
      \  {
      \    'command':'continue',
      \    'flags':s:or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'confirm',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:CMDWIN),
      \  },
      \  {
      \    'command':'copen',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'cprevious',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cpfile',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cquit',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:ZEROR, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'crewind',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cscope',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:XFILE),
      \  },
      \  {
      \    'command':'cstag',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'cunmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cunabbrev',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cunmenu',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cwindow',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'delete',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:REGSTR, s:COUNT, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'delmarks',
      \    'flags':s:or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'debug',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'debuggreedy',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'delcommand',
      \    'flags':s:or(s:BANG, s:NEEDARG, s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'delfunction',
      \    'flags':s:or(s:BANG, s:NEEDARG, s:WORD1, s:CMDWIN),
      \  },
      \  {
      \    'command':'display',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'diffupdate',
      \    'flags':s:or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'diffget',
      \    'flags':s:or(s:RANGE, s:EXTRA, s:TRLBAR, s:MODIFY),
      \  },
      \  {
      \    'command':'diffoff',
      \    'flags':s:or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'diffpatch',
      \    'flags':s:or(s:EXTRA, s:FILE1, s:TRLBAR, s:MODIFY),
      \  },
      \  {
      \    'command':'diffput',
      \    'flags':s:or(s:RANGE, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'diffsplit',
      \    'flags':s:or(s:EXTRA, s:FILE1, s:TRLBAR),
      \  },
      \  {
      \    'command':'diffthis',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'digraphs',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'djump',
      \    'flags':s:or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA),
      \  },
      \  {
      \    'command':'dlist',
      \    'flags':s:or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'doautocmd',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'doautoall',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'drop',
      \    'flags':s:or(s:FILES, s:EDITCMD, s:NEEDARG, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'dsearch',
      \    'flags':s:or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'dsplit',
      \    'flags':s:or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA),
      \  },
      \  {
      \    'command':'edit',
      \    'flags':s:or(s:BANG, s:FILE1, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'earlier',
      \    'flags':s:or(s:TRLBAR, s:EXTRA, s:NOSPC, s:CMDWIN),
      \  },
      \  {
      \    'command':'echo',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'echoerr',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'echohl',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'echomsg',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'echon',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'else',
      \    'flags':s:or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'elseif',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'emenu',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:RANGE, s:NOTADR, s:CMDWIN),
      \  },
      \  {
      \    'command':'endif',
      \    'flags':s:or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'endfunction',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'endfor',
      \    'flags':s:or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'endtry',
      \    'flags':s:or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'endwhile',
      \    'flags':s:or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'enew',
      \    'flags':s:or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'ex',
      \    'flags':s:or(s:BANG, s:FILE1, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'execute',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'exit',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:BANG, s:FILE1, s:ARGOPT, s:DFLALL, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'exusage',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'file',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:BANG, s:FILE1, s:TRLBAR),
      \  },
      \  {
      \    'command':'files',
      \    'flags':s:or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'filetype',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'filter',
      \    'flags':s:or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'find',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:FILE1, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'finally',
      \    'flags':s:or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'finish',
      \    'flags':s:or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'first',
      \    'flags':s:or(s:EXTRA, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'fold',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'foldclose',
      \    'flags':s:or(s:RANGE, s:BANG, s:WHOLEFOLD, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'folddoopen',
      \    'flags':s:or(s:RANGE, s:DFLALL, s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'folddoclosed',
      \    'flags':s:or(s:RANGE, s:DFLALL, s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'foldopen',
      \    'flags':s:or(s:RANGE, s:BANG, s:WHOLEFOLD, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'for',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'function',
      \    'flags':s:or(s:EXTRA, s:BANG, s:CMDWIN),
      \  },
      \  {
      \    'command':'global',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:BANG, s:EXTRA, s:DFLALL, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'goto',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'grep',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'grepadd',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'gui',
      \    'flags':s:or(s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'gvim',
      \    'flags':s:or(s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'help',
      \    'flags':s:or(s:BANG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'helpclose',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'helpgrep',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:NEEDARG),
      \  },
      \  {
      \    'command':'helptags',
      \    'flags':s:or(s:NEEDARG, s:FILES, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'hardcopy',
      \    'flags':s:or(s:RANGE, s:COUNT, s:EXTRA, s:TRLBAR, s:DFLALL, s:BANG),
      \  },
      \  {
      \    'command':'highlight',
      \    'flags':s:or(s:BANG, s:EXTRA, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'hide',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'history',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'insert',
      \    'flags':s:or(s:BANG, s:RANGE, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'iabbrev',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'iabclear',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'if',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'ijump',
      \    'flags':s:or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA),
      \  },
      \  {
      \    'command':'ilist',
      \    'flags':s:or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'imap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'imapclear',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'imenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'inoremap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'inoreabbrev',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'inoremenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'intro',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'isearch',
      \    'flags':s:or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'isplit',
      \    'flags':s:or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA),
      \  },
      \  {
      \    'command':'iunmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'iunabbrev',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'iunmenu',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'join',
      \    'flags':s:or(s:BANG, s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'jumps',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'k',
      \    'flags':s:or(s:RANGE, s:WORD1, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'keepmarks',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'keepjumps',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'keeppatterns',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'keepalt',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'list',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'lNext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'lNfile',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'last',
      \    'flags':s:or(s:EXTRA, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'language',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'laddexpr',
      \    'flags':s:or(s:NEEDARG, s:WORD1, s:NOTRLCOM, s:TRLBAR),
      \  },
      \  {
      \    'command':'laddbuffer',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:WORD1, s:TRLBAR),
      \  },
      \  {
      \    'command':'laddfile',
      \    'flags':s:or(s:TRLBAR, s:FILE1),
      \  },
      \  {
      \    'command':'later',
      \    'flags':s:or(s:TRLBAR, s:EXTRA, s:NOSPC, s:CMDWIN),
      \  },
      \  {
      \    'command':'lbuffer',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:WORD1, s:TRLBAR),
      \  },
      \  {
      \    'command':'lbottom',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'lcd',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'lchdir',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'lclose',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'lcscope',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:XFILE),
      \  },
      \  {
      \    'command':'ldo',
      \    'flags':s:or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'left',
      \    'flags':s:or(s:TRLBAR, s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'leftabove',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'let',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'lexpr',
      \    'flags':s:or(s:NEEDARG, s:WORD1, s:NOTRLCOM, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'lfile',
      \    'flags':s:or(s:TRLBAR, s:FILE1, s:BANG),
      \  },
      \  {
      \    'command':'lfdo',
      \    'flags':s:or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'lfirst',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'lgetfile',
      \    'flags':s:or(s:TRLBAR, s:FILE1),
      \  },
      \  {
      \    'command':'lgetbuffer',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:WORD1, s:TRLBAR),
      \  },
      \  {
      \    'command':'lgetexpr',
      \    'flags':s:or(s:NEEDARG, s:WORD1, s:NOTRLCOM, s:TRLBAR),
      \  },
      \  {
      \    'command':'lgrep',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'lgrepadd',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'lhelpgrep',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:NEEDARG),
      \  },
      \  {
      \    'command':'lhistory',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'ll',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'llast',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'llist',
      \    'flags':s:or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'lmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'lmapclear',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'lmake',
      \    'flags':s:or(s:BANG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'lnoremap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'lnext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'lnewer',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'lnfile',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'loadview',
      \    'flags':s:or(s:FILE1, s:TRLBAR),
      \  },
      \  {
      \    'command':'loadkeymap',
      \    'flags':s:or(s:CMDWIN),
      \  },
      \  {
      \    'command':'lockmarks',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'lockvar',
      \    'flags':s:or(s:BANG, s:EXTRA, s:NEEDARG, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'lolder',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'lopen',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'lprevious',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'lpfile',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'lrewind',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'ltag',
      \    'flags':s:or(s:NOTADR, s:TRLBAR, s:BANG, s:WORD1),
      \  },
      \  {
      \    'command':'lunmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'lua',
      \    'flags':s:or(s:RANGE, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'luado',
      \    'flags':s:or(s:RANGE, s:DFLALL, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'luafile',
      \    'flags':s:or(s:RANGE, s:FILE1, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'lvimgrep',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'lvimgrepadd',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'lwindow',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'ls',
      \    'flags':s:or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'move',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'mark',
      \    'flags':s:or(s:RANGE, s:WORD1, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'make',
      \    'flags':s:or(s:BANG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'map',
      \    'flags':s:or(s:BANG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'mapclear',
      \    'flags':s:or(s:EXTRA, s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'marks',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'match',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'menu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:BANG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'menutranslate',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'messages',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:RANGE, s:CMDWIN),
      \  },
      \  {
      \    'command':'mkexrc',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'mksession',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR),
      \  },
      \  {
      \    'command':'mkspell',
      \    'flags':s:or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'mkvimrc',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'mkview',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR),
      \  },
      \  {
      \    'command':'mode',
      \    'flags':s:or(s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'mzscheme',
      \    'flags':s:or(s:RANGE, s:EXTRA, s:DFLALL, s:NEEDARG, s:CMDWIN, s:SBOXOK),
      \  },
      \  {
      \    'command':'mzfile',
      \    'flags':s:or(s:RANGE, s:FILE1, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'next',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'nbkey',
      \    'flags':s:or(s:EXTRA, s:NOTADR, s:NEEDARG),
      \  },
      \  {
      \    'command':'nbclose',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'nbstart',
      \    'flags':s:or(s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'new',
      \    'flags':s:or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'nmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'nmapclear',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'nmenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'nnoremap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'nnoremenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'noremap',
      \    'flags':s:or(s:BANG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'noautocmd',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'nohlsearch',
      \    'flags':s:or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'noreabbrev',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'noremenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:BANG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'noswapfile',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'normal',
      \    'flags':s:or(s:RANGE, s:BANG, s:EXTRA, s:NEEDARG, s:NOTRLCOM, s:USECTRLV, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'number',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'nunmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'nunmenu',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'oldfiles',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'omap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'omapclear',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'omenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'only',
      \    'flags':s:or(s:BANG, s:NOTADR, s:RANGE, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'onoremap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'onoremenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'options',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'ounmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'ounmenu',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'ownsyntax',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'print',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN, s:SBOXOK),
      \  },
      \  {
      \    'command':'packadd',
      \    'flags':s:or(s:BANG, s:FILE1, s:NEEDARG, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'packloadall',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'pclose',
      \    'flags':s:or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'perl',
      \    'flags':s:or(s:RANGE, s:EXTRA, s:DFLALL, s:NEEDARG, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'perldo',
      \    'flags':s:or(s:RANGE, s:EXTRA, s:DFLALL, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'pedit',
      \    'flags':s:or(s:BANG, s:FILE1, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'pop',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:COUNT, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'popup',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:BANG, s:TRLBAR, s:NOTRLCOM, s:CMDWIN),
      \  },
      \  {
      \    'command':'ppop',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:COUNT, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'preserve',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'previous',
      \    'flags':s:or(s:EXTRA, s:RANGE, s:NOTADR, s:COUNT, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'promptfind',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:CMDWIN),
      \  },
      \  {
      \    'command':'promptrepl',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:CMDWIN),
      \  },
      \  {
      \    'command':'profile',
      \    'flags':s:or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'profdel',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'psearch',
      \    'flags':s:or(s:BANG, s:RANGE, s:WHOLEFOLD, s:DFLALL, s:EXTRA),
      \  },
      \  {
      \    'command':'ptag',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:WORD1, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'ptNext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'ptfirst',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'ptjump',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'ptlast',
      \    'flags':s:or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'ptnext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'ptprevious',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'ptrewind',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'ptselect',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'put',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:BANG, s:REGSTR, s:TRLBAR, s:ZEROR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'pwd',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'python',
      \    'flags':s:or(s:RANGE, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'pydo',
      \    'flags':s:or(s:RANGE, s:DFLALL, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'pyfile',
      \    'flags':s:or(s:RANGE, s:FILE1, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'py3',
      \    'flags':s:or(s:RANGE, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'py3do',
      \    'flags':s:or(s:RANGE, s:DFLALL, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'python3',
      \    'flags':s:or(s:RANGE, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'py3file',
      \    'flags':s:or(s:RANGE, s:FILE1, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'quit',
      \    'flags':s:or(s:BANG, s:RANGE, s:COUNT, s:NOTADR, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'quitall',
      \    'flags':s:or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'qall',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'read',
      \    'flags':s:or(s:BANG, s:RANGE, s:WHOLEFOLD, s:FILE1, s:ARGOPT, s:TRLBAR, s:ZEROR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'recover',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR),
      \  },
      \  {
      \    'command':'redo',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'redir',
      \    'flags':s:or(s:BANG, s:FILES, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'redraw',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'redrawstatus',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'registers',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'resize',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:TRLBAR, s:WORD1, s:CMDWIN),
      \  },
      \  {
      \    'command':'retab',
      \    'flags':s:or(s:TRLBAR, s:RANGE, s:WHOLEFOLD, s:DFLALL, s:BANG, s:WORD1, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'return',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'rewind',
      \    'flags':s:or(s:EXTRA, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'right',
      \    'flags':s:or(s:TRLBAR, s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'rightbelow',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'rshada',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'runtime',
      \    'flags':s:or(s:BANG, s:NEEDARG, s:FILES, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'rundo',
      \    'flags':s:or(s:NEEDARG, s:FILE1),
      \  },
      \  {
      \    'command':'ruby',
      \    'flags':s:or(s:RANGE, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'rubydo',
      \    'flags':s:or(s:RANGE, s:DFLALL, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'rubyfile',
      \    'flags':s:or(s:RANGE, s:FILE1, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'rviminfo',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'substitute',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'sNext',
      \    'flags':s:or(s:EXTRA, s:RANGE, s:NOTADR, s:COUNT, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'sargument',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EXTRA, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'sall',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'sandbox',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'saveas',
      \    'flags':s:or(s:BANG, s:DFLALL, s:FILE1, s:ARGOPT, s:CMDWIN, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbuffer',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:BUFNAME, s:BUFUNL, s:COUNT, s:EXTRA, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbNext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sball',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbfirst',
      \    'flags':s:or(s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sblast',
      \    'flags':s:or(s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbmodified',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbnext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbprevious',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbrewind',
      \    'flags':s:or(s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'scriptnames',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'scriptencoding',
      \    'flags':s:or(s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'scscope',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'set',
      \    'flags':s:or(s:TRLBAR, s:EXTRA, s:CMDWIN, s:SBOXOK),
      \  },
      \  {
      \    'command':'setfiletype',
      \    'flags':s:or(s:TRLBAR, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'setglobal',
      \    'flags':s:or(s:TRLBAR, s:EXTRA, s:CMDWIN, s:SBOXOK),
      \  },
      \  {
      \    'command':'setlocal',
      \    'flags':s:or(s:TRLBAR, s:EXTRA, s:CMDWIN, s:SBOXOK),
      \  },
      \  {
      \    'command':'sfind',
      \    'flags':s:or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'sfirst',
      \    'flags':s:or(s:EXTRA, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'simalt',
      \    'flags':s:or(s:NEEDARG, s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'sign',
      \    'flags':s:or(s:NEEDARG, s:RANGE, s:NOTADR, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'silent',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:BANG, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'sleep',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'slast',
      \    'flags':s:or(s:EXTRA, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'smagic',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'smap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'smapclear',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'smenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'snext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'snomagic',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'snoremap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'snoremenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'source',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'sort',
      \    'flags':s:or(s:RANGE, s:DFLALL, s:WHOLEFOLD, s:BANG, s:EXTRA, s:NOTRLCOM, s:MODIFY),
      \  },
      \  {
      \    'command':'split',
      \    'flags':s:or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'spellgood',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:NEEDARG, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'spelldump',
      \    'flags':s:or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'spellinfo',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'spellrepall',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'spellundo',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:NEEDARG, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'spellwrong',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:NEEDARG, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'sprevious',
      \    'flags':s:or(s:EXTRA, s:RANGE, s:NOTADR, s:COUNT, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'srewind',
      \    'flags':s:or(s:EXTRA, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'stop',
      \    'flags':s:or(s:TRLBAR, s:BANG, s:CMDWIN),
      \  },
      \  {
      \    'command':'stag',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:WORD1, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'startinsert',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'startgreplace',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'startreplace',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'stopinsert',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'stjump',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'stselect',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'sunhide',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'sunmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'sunmenu',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'suspend',
      \    'flags':s:or(s:TRLBAR, s:BANG, s:CMDWIN),
      \  },
      \  {
      \    'command':'sview',
      \    'flags':s:or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'swapname',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'syntax',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:CMDWIN),
      \  },
      \  {
      \    'command':'syntime',
      \    'flags':s:or(s:NEEDARG, s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'syncbind',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'t',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'tcd',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tchdir',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tNext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'tag',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:WORD1, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'tags',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tab',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'tabclose',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:NOSPC, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tabdo',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'tabedit',
      \    'flags':s:or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:ZEROR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'tabfind',
      \    'flags':s:or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:ZEROR, s:EDITCMD, s:ARGOPT, s:NEEDARG, s:TRLBAR),
      \  },
      \  {
      \    'command':'tabfirst',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'tabmove',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:NOSPC, s:TRLBAR),
      \  },
      \  {
      \    'command':'tablast',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'tabnext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:NOSPC, s:TRLBAR),
      \  },
      \  {
      \    'command':'tabnew',
      \    'flags':s:or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:ZEROR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'tabonly',
      \    'flags':s:or(s:BANG, s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:NOSPC, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tabprevious',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:NOSPC, s:TRLBAR),
      \  },
      \  {
      \    'command':'tabNext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:NOSPC, s:TRLBAR),
      \  },
      \  {
      \    'command':'tabrewind',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'tabs',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tcl',
      \    'flags':s:or(s:RANGE,s:EXTRA,s:NEEDARG,s:CMDWIN),
      \  },
      \  {
      \    'command':'tcldo',
      \    'flags':s:or(s:RANGE,s:DFLALL,s:EXTRA,s:NEEDARG,s:CMDWIN),
      \  },
      \  {
      \    'command':'tclfile',
      \    'flags':s:or(s:RANGE,s:FILE1,s:NEEDARG,s:CMDWIN),
      \  },
      \  {
      \    'command':'terminal',
      \    'flags':s:or(s:BANG, s:FILES, s:CMDWIN),
      \  },
      \  {
      \    'command':'tfirst',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'throw',
      \    'flags':s:or(s:EXTRA, s:NEEDARG, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'tjump',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'tlast',
      \    'flags':s:or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'tmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'tmapclear',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tmenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'tnext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'tnoremap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'topleft',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'tprevious',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'trewind',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'try',
      \    'flags':s:or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'tselect',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'tunmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'tunmenu',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'undo',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:ZEROR, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'undojoin',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'undolist',
      \    'flags':s:or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'unabbreviate',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'unhide',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'unlet',
      \    'flags':s:or(s:BANG, s:EXTRA, s:NEEDARG, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'unlockvar',
      \    'flags':s:or(s:BANG, s:EXTRA, s:NEEDARG, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'unmap',
      \    'flags':s:or(s:BANG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'unmenu',
      \    'flags':s:or(s:BANG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'unsilent',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'update',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:BANG, s:FILE1, s:ARGOPT, s:DFLALL, s:TRLBAR),
      \  },
      \  {
      \    'command':'vglobal',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:DFLALL, s:CMDWIN),
      \  },
      \  {
      \    'command':'version',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'verbose',
      \    'flags':s:or(s:NEEDARG, s:RANGE, s:NOTADR, s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'vertical',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'visual',
      \    'flags':s:or(s:BANG, s:FILE1, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'view',
      \    'flags':s:or(s:BANG, s:FILE1, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'vimgrep',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'vimgrepadd',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'viusage',
      \    'flags':s:or(s:TRLBAR),
      \  },
      \  {
      \    'command':'vmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'vmapclear',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'vmenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'vnoremap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'vnew',
      \    'flags':s:or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'vnoremenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'vsplit',
      \    'flags':s:or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'vunmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'vunmenu',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'write',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:BANG, s:FILE1, s:ARGOPT, s:DFLALL, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'wNext',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:NOTADR, s:BANG, s:FILE1, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'wall',
      \    'flags':s:or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'while',
      \    'flags':s:or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'winsize',
      \    'flags':s:or(s:EXTRA, s:NEEDARG, s:TRLBAR),
      \  },
      \  {
      \    'command':'wincmd',
      \    'flags':s:or(s:NEEDARG, s:WORD1, s:RANGE, s:NOTADR, s:CMDWIN),
      \  },
      \  {
      \    'command':'windo',
      \    'flags':s:or(s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'winpos',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'wnext',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:FILE1, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'wprevious',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:BANG, s:FILE1, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'wq',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:BANG, s:FILE1, s:ARGOPT, s:DFLALL, s:TRLBAR),
      \  },
      \  {
      \    'command':'wqall',
      \    'flags':s:or(s:BANG, s:FILE1, s:ARGOPT, s:DFLALL, s:TRLBAR),
      \  },
      \  {
      \    'command':'wsverb',
      \    'flags':s:or(s:EXTRA, s:NOTADR, s:NEEDARG),
      \  },
      \  {
      \    'command':'wshada',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'wundo',
      \    'flags':s:or(s:BANG, s:NEEDARG, s:FILE1),
      \  },
      \  {
      \    'command':'wviminfo',
      \    'flags':s:or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'xit',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:BANG, s:FILE1, s:ARGOPT, s:DFLALL, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'xall',
      \    'flags':s:or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'xmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'xmapclear',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'xmenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'xnoremap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'xnoremenu',
      \    'flags':s:or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'xunmap',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'xunmenu',
      \    'flags':s:or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'yank',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:REGSTR, s:COUNT, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'z',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:EXFLAGS, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'!',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:BANG, s:FILES, s:CMDWIN),
      \  },
      \  {
      \    'command':'#',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'&',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'<',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':':',
      \    'flags':s:or(s:RANGE, s:TRLBAR, s:DFLALL, s:EXFLAGS, s:CMDWIN),
      \  },
      \  {
      \    'command':'>',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'@',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'Next',
      \    'flags':s:or(s:EXTRA, s:RANGE, s:NOTADR, s:COUNT, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'~',
      \    'flags':s:or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN, s:MODIFY),
      \  },
      \]

let s:command_map = {}

for s:cmd in s:commands
  let s:command_map[s:cmd.command] = s:cmd
endfor
