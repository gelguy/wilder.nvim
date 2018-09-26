function! wildsearch#getcompletion#main#do(ctx) abort
  if empty(a:ctx.cmdline[a:ctx.pos :])
    return
  endif

  if !wildsearch#getcompletion#skip_whitespace(a:ctx)
    return
  endif

  " check if comment
  if a:ctx.cmdline[a:ctx.pos] ==# '"'
    let a:ctx.pos = len(a:ctx.cmdline)
    return
  endif

  " skip range
  call wildsearch#getcompletion#skip_range#do(a:ctx)

  if !wildsearch#getcompletion#skip_whitespace(a:ctx)
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

    call wildsearch#getcompletion#main#do(a:ctx)

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

  if !wildsearch#getcompletion#skip_whitespace(a:ctx)
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

      if !wildsearch#getcompletion#skip_whitespace(a:ctx)
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

    if !wildsearch#getcompletion#skip_whitespace(a:ctx)
      return
    endif
  endif

  " +command
  if and(l:flags, s:EDITCMD) &&
        \ !l:use_filter && a:ctx.cmdline[a:ctx.pos] ==# '+'
    call wildsearch#getcompletion#skip_plus_command#do(a:ctx)
  endif

  if !wildsearch#getcompletion#skip_whitespace(a:ctx)
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

        call wildsearch#getcompletion#main#do(a:ctx)

        return
      endif

      " TODO: multibyte
      let l:lookahead += 1
    endwhile
  endif

  " command does not take extra arguments
  if !and(l:flags, s:EXTRA) && !l:is_user_cmd
    " consume whitespace
    if !wildsearch#getcompletion#skip_whitespace(a:ctx)
      return
    endif

    " and check for | or "
    if a:ctx.cmdline[a:ctx.pos] ==# '|'
      let a:ctx.pos += 1
      let a:ctx.cmd = ''

      call wildsearch#getcompletion#main#do(a:ctx)
      return
    else
      " remaining part is either comment or invalid arguments
      " either way, treat as no arguments
      let a:ctx.pos = len(a:ctx.cmdline)
      return
    endif
  endif

  if !wildsearch#getcompletion#skip_whitespace(a:ctx)
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

    call wildsearch#getcompletion#main#do(a:ctx)

    return
  endif

  if a:ctx.cmd ==# 'filter'
    call wildsearch#getcompletion#filter#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'match'
    call wildsearch#getcompletion#match#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'command'
    call wildsearch#getcompletion#command#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'global' || a:ctx.cmd ==# 'vglobal'
    call wildsearch#getcompletion#global#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# '&' || a:ctx.cmd ==# 'substitute'
    call wildsearch#getcompletion#substitute#do(a:ctx)
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
    call wildsearch#getcompletion#isearch#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'autocmd' ||
        \ a:ctx.cmd ==# 'doautocmd' ||
        \ a:ctx.cmd ==# 'doautoall'
    call wildsearch#getcompletion#autocmd#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'set' ||
        \ a:ctx.cmd ==# 'setglobal' ||
        \ a:ctx.cmd ==# 'setlocal'
    call wildsearch#getcompletion#set#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'syntax'
    call wildsearch#getcompletion#syntax#do(a:ctx)
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
    call wildsearch#getcompletion#let#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'highlight'
    call wildsearch#getcompletion#highlight#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'cscope' ||
        \ a:ctx.cmd ==# 'lcscope' ||
        \ a:ctx.cmd ==# 'scscope'
    call wildsearch#getcompletion#cscope#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'sign'
    call wildsearch#getcompletion#sign#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'abbreviate' ||
        \ a:ctx.cmd ==# 'unabbreviate' ||
        \ match(a:ctx.cmd, 'map$') != -1 ||
        \ match(a:ctx.cmd, 'abbrev$') != -1
    call wildsearch#getcompletion#map#do(a:ctx)
    return
  endif

  if match(a:ctx.cmd, 'menu$') != -1
    call wildsearch#getcompletion#menu#do(a:ctx)
    return
  endif

  if a:ctx.cmd ==# 'profile'
    call wildsearch#getcompletion#profile#do(a:ctx)
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
  " this is ok, since wildsearch#getcompletion() will return no results
  let l:arg_start = a:ctx.pos

  while a:ctx.pos < len(a:ctx.cmdline)
    let l:char = a:ctx.cmdline[a:ctx.pos]

    if l:char ==# '\'
      if a:ctx.pos + 1 < len(a:ctx.cmdline)
        let a:ctx.pos += 1
      endif
    elseif wildsearch#getcompletion#is_whitespace(l:char)
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

function! wildsearch#getcompletion#main#has_file_args(cmd) abort
  let l:command = get(s:command_map, a:cmd, {})
  let l:flags = get(l:command, 'flags', 0)
  return and(l:flags, s:XFILE)
endfunction

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
let s:FILES      = wildsearch#getcompletion#or(s:XFILE, s:EXTRA)
let s:WORD1      = wildsearch#getcompletion#or(s:EXTRA, s:NOSPC)
let s:FILE1      = wildsearch#getcompletion#or(s:FILES, s:NOSPC)

let s:commands = [
      \  {
      \    'command':'append',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:ZEROR, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'abbreviate',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'abclear',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'aboveleft',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'all',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'amenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'anoremenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'args',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'argadd',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:ZEROR, s:FILES, s:TRLBAR),
      \  },
      \  {
      \    'command':'argdelete',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:FILES, s:TRLBAR),
      \  },
      \  {
      \    'command':'argdo',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'argedit',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NEEDARG, s:RANGE, s:NOTADR, s:ZEROR, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'argglobal',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'arglocal',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'argument',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EXTRA, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'ascii',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'autocmd',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'augroup',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'aunmenu',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'buffer',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:BUFNAME, s:BUFUNL, s:COUNT, s:EXTRA, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'bNext',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'ball',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'badd',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:FILE1, s:EDITCMD, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'bdelete',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:BUFNAME, s:COUNT, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'behave',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'belowright',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'bfirst',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'blast',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'bmodified',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'bnext',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'botright',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'bprevious',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'brewind',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'break',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'breakadd',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'breakdel',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'breaklist',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'browse',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:CMDWIN),
      \  },
      \  {
      \    'command':'buffers',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'bufdo',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'bunload',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:BUFNAME, s:COUNT, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'bwipeout',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:BUFNAME, s:BUFUNL, s:COUNT, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'change',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:WHOLEFOLD, s:RANGE, s:COUNT, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'cNext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cNfile',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cabbrev',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cabclear',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'caddbuffer',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:WORD1, s:TRLBAR),
      \  },
      \  {
      \    'command':'caddexpr',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:WORD1, s:NOTRLCOM, s:TRLBAR),
      \  },
      \  {
      \    'command':'caddfile',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:FILE1),
      \  },
      \  {
      \    'command':'call',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'catch',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'cbuffer',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:WORD1, s:TRLBAR),
      \  },
      \  {
      \    'command':'cbottom',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'cc',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cclose',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'cd',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'cdo',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'center',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'cexpr',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:WORD1, s:NOTRLCOM, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cfile',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:FILE1, s:BANG),
      \  },
      \  {
      \    'command':'cfdo',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'cfirst',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cgetfile',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:FILE1),
      \  },
      \  {
      \    'command':'cgetbuffer',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:WORD1, s:TRLBAR),
      \  },
      \  {
      \    'command':'cgetexpr',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:WORD1, s:NOTRLCOM, s:TRLBAR),
      \  },
      \  {
      \    'command':'chdir',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'changes',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'checkhealth',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'checkpath',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:BANG, s:CMDWIN),
      \  },
      \  {
      \    'command':'checktime',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BUFNAME, s:COUNT, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'chistory',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'clist',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'clast',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'close',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'clearjumps',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'cmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cmapclear',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'cmenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cnext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cnewer',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'cnfile',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cnoremap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cnoreabbrev',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cnoremenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'copy',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'colder',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'colorscheme',
      \    'flags':wildsearch#getcompletion#or(s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'command',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:BANG, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'comclear',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'compiler',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:WORD1, s:CMDWIN),
      \  },
      \  {
      \    'command':'continue',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'confirm',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:CMDWIN),
      \  },
      \  {
      \    'command':'copen',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'cprevious',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cpfile',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cquit',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:ZEROR, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'crewind',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'cscope',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:XFILE),
      \  },
      \  {
      \    'command':'cstag',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'cunmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cunabbrev',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cunmenu',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'cwindow',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'delete',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:REGSTR, s:COUNT, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'delmarks',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'debug',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'debuggreedy',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'delcommand',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NEEDARG, s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'delfunction',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NEEDARG, s:WORD1, s:CMDWIN),
      \  },
      \  {
      \    'command':'display',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'diffupdate',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'diffget',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:EXTRA, s:TRLBAR, s:MODIFY),
      \  },
      \  {
      \    'command':'diffoff',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'diffpatch',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:FILE1, s:TRLBAR, s:MODIFY),
      \  },
      \  {
      \    'command':'diffput',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'diffsplit',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:FILE1, s:TRLBAR),
      \  },
      \  {
      \    'command':'diffthis',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'digraphs',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'djump',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA),
      \  },
      \  {
      \    'command':'dlist',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'doautocmd',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'doautoall',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'drop',
      \    'flags':wildsearch#getcompletion#or(s:FILES, s:EDITCMD, s:NEEDARG, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'dsearch',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'dsplit',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA),
      \  },
      \  {
      \    'command':'edit',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'earlier',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:EXTRA, s:NOSPC, s:CMDWIN),
      \  },
      \  {
      \    'command':'echo',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'echoerr',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'echohl',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'echomsg',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'echon',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'else',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'elseif',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'emenu',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:RANGE, s:NOTADR, s:CMDWIN),
      \  },
      \  {
      \    'command':'endif',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'endfunction',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'endfor',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'endtry',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'endwhile',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'enew',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'ex',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'execute',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'exit',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:BANG, s:FILE1, s:ARGOPT, s:DFLALL, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'exusage',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'file',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:BANG, s:FILE1, s:TRLBAR),
      \  },
      \  {
      \    'command':'files',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'filetype',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'filter',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'find',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:FILE1, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'finally',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'finish',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'first',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'fold',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'foldclose',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:BANG, s:WHOLEFOLD, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'folddoopen',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:DFLALL, s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'folddoclosed',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:DFLALL, s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'foldopen',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:BANG, s:WHOLEFOLD, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'for',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'function',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:BANG, s:CMDWIN),
      \  },
      \  {
      \    'command':'global',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:BANG, s:EXTRA, s:DFLALL, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'goto',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'grep',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'grepadd',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'gui',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'gvim',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'help',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'helpclose',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'helpgrep',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:NEEDARG),
      \  },
      \  {
      \    'command':'helptags',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:FILES, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'hardcopy',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:COUNT, s:EXTRA, s:TRLBAR, s:DFLALL, s:BANG),
      \  },
      \  {
      \    'command':'highlight',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'hide',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'history',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'insert',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'iabbrev',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'iabclear',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'if',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'ijump',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA),
      \  },
      \  {
      \    'command':'ilist',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'imap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'imapclear',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'imenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'inoremap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'inoreabbrev',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'inoremenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'intro',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'isearch',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'isplit',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:DFLALL, s:WHOLEFOLD, s:EXTRA),
      \  },
      \  {
      \    'command':'iunmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'iunabbrev',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'iunmenu',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'join',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'jumps',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'k',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WORD1, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'keepmarks',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'keepjumps',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'keeppatterns',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'keepalt',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'list',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'lNext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'lNfile',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'last',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'language',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'laddexpr',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:WORD1, s:NOTRLCOM, s:TRLBAR),
      \  },
      \  {
      \    'command':'laddbuffer',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:WORD1, s:TRLBAR),
      \  },
      \  {
      \    'command':'laddfile',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:FILE1),
      \  },
      \  {
      \    'command':'later',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:EXTRA, s:NOSPC, s:CMDWIN),
      \  },
      \  {
      \    'command':'lbuffer',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:WORD1, s:TRLBAR),
      \  },
      \  {
      \    'command':'lbottom',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'lcd',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'lchdir',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'lclose',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'lcscope',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:XFILE),
      \  },
      \  {
      \    'command':'ldo',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'left',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'leftabove',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'let',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'lexpr',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:WORD1, s:NOTRLCOM, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'lfile',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:FILE1, s:BANG),
      \  },
      \  {
      \    'command':'lfdo',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'lfirst',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'lgetfile',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:FILE1),
      \  },
      \  {
      \    'command':'lgetbuffer',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:WORD1, s:TRLBAR),
      \  },
      \  {
      \    'command':'lgetexpr',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:WORD1, s:NOTRLCOM, s:TRLBAR),
      \  },
      \  {
      \    'command':'lgrep',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'lgrepadd',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'lhelpgrep',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:NEEDARG),
      \  },
      \  {
      \    'command':'lhistory',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'ll',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'llast',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'llist',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'lmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'lmapclear',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'lmake',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'lnoremap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'lnext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'lnewer',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'lnfile',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'loadview',
      \    'flags':wildsearch#getcompletion#or(s:FILE1, s:TRLBAR),
      \  },
      \  {
      \    'command':'loadkeymap',
      \    'flags':wildsearch#getcompletion#or(s:CMDWIN),
      \  },
      \  {
      \    'command':'lockmarks',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'lockvar',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:NEEDARG, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'lolder',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'lopen',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'lprevious',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'lpfile',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'lrewind',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR, s:BANG),
      \  },
      \  {
      \    'command':'ltag',
      \    'flags':wildsearch#getcompletion#or(s:NOTADR, s:TRLBAR, s:BANG, s:WORD1),
      \  },
      \  {
      \    'command':'lunmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'lua',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'luado',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:DFLALL, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'luafile',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:FILE1, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'lvimgrep',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'lvimgrepadd',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'lwindow',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'ls',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'move',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'mark',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WORD1, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'make',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'map',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'mapclear',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'marks',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'match',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'menu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:BANG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'menutranslate',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'messages',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:RANGE, s:CMDWIN),
      \  },
      \  {
      \    'command':'mkexrc',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'mksession',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR),
      \  },
      \  {
      \    'command':'mkspell',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'mkvimrc',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'mkview',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR),
      \  },
      \  {
      \    'command':'mode',
      \    'flags':wildsearch#getcompletion#or(s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'mzscheme',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:EXTRA, s:DFLALL, s:NEEDARG, s:CMDWIN, s:SBOXOK),
      \  },
      \  {
      \    'command':'mzfile',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:FILE1, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'next',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'nbkey',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTADR, s:NEEDARG),
      \  },
      \  {
      \    'command':'nbclose',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'nbstart',
      \    'flags':wildsearch#getcompletion#or(s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'new',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'nmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'nmapclear',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'nmenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'nnoremap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'nnoremenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'noremap',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'noautocmd',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'nohlsearch',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'noreabbrev',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'noremenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:BANG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'noswapfile',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'normal',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:BANG, s:EXTRA, s:NEEDARG, s:NOTRLCOM, s:USECTRLV, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'number',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'nunmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'nunmenu',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'oldfiles',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'omap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'omapclear',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'omenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'only',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NOTADR, s:RANGE, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'onoremap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'onoremenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'options',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'ounmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'ounmenu',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'ownsyntax',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'print',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN, s:SBOXOK),
      \  },
      \  {
      \    'command':'packadd',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:NEEDARG, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'packloadall',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'pclose',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'perl',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:EXTRA, s:DFLALL, s:NEEDARG, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'perldo',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:EXTRA, s:DFLALL, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'pedit',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'pop',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:COUNT, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'popup',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:BANG, s:TRLBAR, s:NOTRLCOM, s:CMDWIN),
      \  },
      \  {
      \    'command':'ppop',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:COUNT, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'preserve',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'previous',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:RANGE, s:NOTADR, s:COUNT, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'promptfind',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:CMDWIN),
      \  },
      \  {
      \    'command':'promptrepl',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:CMDWIN),
      \  },
      \  {
      \    'command':'profile',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'profdel',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'psearch',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:WHOLEFOLD, s:DFLALL, s:EXTRA),
      \  },
      \  {
      \    'command':'ptag',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:WORD1, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'ptNext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'ptfirst',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'ptjump',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'ptlast',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'ptnext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'ptprevious',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'ptrewind',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'ptselect',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'put',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:BANG, s:REGSTR, s:TRLBAR, s:ZEROR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'pwd',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'python',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'pydo',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:DFLALL, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'pyfile',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:FILE1, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'py3',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'py3do',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:DFLALL, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'python3',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'py3file',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:FILE1, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'quit',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:COUNT, s:NOTADR, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'quitall',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'qall',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'read',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:WHOLEFOLD, s:FILE1, s:ARGOPT, s:TRLBAR, s:ZEROR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'recover',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR),
      \  },
      \  {
      \    'command':'redo',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'redir',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILES, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'redraw',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'redrawstatus',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'registers',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'resize',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:TRLBAR, s:WORD1, s:CMDWIN),
      \  },
      \  {
      \    'command':'retab',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:RANGE, s:WHOLEFOLD, s:DFLALL, s:BANG, s:WORD1, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'return',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'rewind',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'right',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'rightbelow',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'rshada',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'runtime',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NEEDARG, s:FILES, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'rundo',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:FILE1),
      \  },
      \  {
      \    'command':'ruby',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'rubydo',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:DFLALL, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'rubyfile',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:FILE1, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'rviminfo',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'substitute',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'sNext',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:RANGE, s:NOTADR, s:COUNT, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'sargument',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:EXTRA, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'sall',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'sandbox',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'saveas',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:DFLALL, s:FILE1, s:ARGOPT, s:CMDWIN, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbuffer',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:BUFNAME, s:BUFUNL, s:COUNT, s:EXTRA, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbNext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sball',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbfirst',
      \    'flags':wildsearch#getcompletion#or(s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sblast',
      \    'flags':wildsearch#getcompletion#or(s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbmodified',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbnext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbprevious',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'sbrewind',
      \    'flags':wildsearch#getcompletion#or(s:EDITCMD, s:TRLBAR),
      \  },
      \  {
      \    'command':'scriptnames',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'scriptencoding',
      \    'flags':wildsearch#getcompletion#or(s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'scscope',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'set',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:EXTRA, s:CMDWIN, s:SBOXOK),
      \  },
      \  {
      \    'command':'setfiletype',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:EXTRA, s:NEEDARG, s:CMDWIN),
      \  },
      \  {
      \    'command':'setglobal',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:EXTRA, s:CMDWIN, s:SBOXOK),
      \  },
      \  {
      \    'command':'setlocal',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:EXTRA, s:CMDWIN, s:SBOXOK),
      \  },
      \  {
      \    'command':'sfind',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'sfirst',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'simalt',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'sign',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:RANGE, s:NOTADR, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'silent',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:BANG, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'sleep',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'slast',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'smagic',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'smap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'smapclear',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'smenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'snext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:FILES, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'snomagic',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN),
      \  },
      \  {
      \    'command':'snoremap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'snoremenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'source',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'sort',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:DFLALL, s:WHOLEFOLD, s:BANG, s:EXTRA, s:NOTRLCOM, s:MODIFY),
      \  },
      \  {
      \    'command':'split',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'spellgood',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:NEEDARG, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'spelldump',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'spellinfo',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'spellrepall',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'spellundo',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:NEEDARG, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'spellwrong',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:NEEDARG, s:EXTRA, s:TRLBAR),
      \  },
      \  {
      \    'command':'sprevious',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:RANGE, s:NOTADR, s:COUNT, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'srewind',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'stop',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:BANG, s:CMDWIN),
      \  },
      \  {
      \    'command':'stag',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:WORD1, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'startinsert',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'startgreplace',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'startreplace',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'stopinsert',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'stjump',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'stselect',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'sunhide',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'sunmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'sunmenu',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'suspend',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:BANG, s:CMDWIN),
      \  },
      \  {
      \    'command':'sview',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'swapname',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'syntax',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:CMDWIN),
      \  },
      \  {
      \    'command':'syntime',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:WORD1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'syncbind',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'t',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'tcd',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tchdir',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tNext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'tag',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:WORD1, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'tags',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tab',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'tabclose',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:NOSPC, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tabdo',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'tabedit',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:ZEROR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'tabfind',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:ZEROR, s:EDITCMD, s:ARGOPT, s:NEEDARG, s:TRLBAR),
      \  },
      \  {
      \    'command':'tabfirst',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'tabmove',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:NOSPC, s:TRLBAR),
      \  },
      \  {
      \    'command':'tablast',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'tabnext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:NOSPC, s:TRLBAR),
      \  },
      \  {
      \    'command':'tabnew',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:ZEROR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'tabonly',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:NOSPC, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tabprevious',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:NOSPC, s:TRLBAR),
      \  },
      \  {
      \    'command':'tabNext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:NOSPC, s:TRLBAR),
      \  },
      \  {
      \    'command':'tabrewind',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'tabs',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tcl',
      \    'flags':wildsearch#getcompletion#or(s:RANGE,s:EXTRA,s:NEEDARG,s:CMDWIN),
      \  },
      \  {
      \    'command':'tcldo',
      \    'flags':wildsearch#getcompletion#or(s:RANGE,s:DFLALL,s:EXTRA,s:NEEDARG,s:CMDWIN),
      \  },
      \  {
      \    'command':'tclfile',
      \    'flags':wildsearch#getcompletion#or(s:RANGE,s:FILE1,s:NEEDARG,s:CMDWIN),
      \  },
      \  {
      \    'command':'terminal',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILES, s:CMDWIN),
      \  },
      \  {
      \    'command':'tfirst',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'throw',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NEEDARG, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'tjump',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'tlast',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'tmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'tmapclear',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'tmenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'tnext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'tnoremap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'topleft',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'tprevious',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'trewind',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:TRLBAR, s:ZEROR),
      \  },
      \  {
      \    'command':'try',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'tselect',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:WORD1),
      \  },
      \  {
      \    'command':'tunmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'tunmenu',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'undo',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:ZEROR, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'undojoin',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'undolist',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'unabbreviate',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'unhide',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:COUNT, s:TRLBAR),
      \  },
      \  {
      \    'command':'unlet',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:NEEDARG, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'unlockvar',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:NEEDARG, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'unmap',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'unmenu',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'unsilent',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'update',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:BANG, s:FILE1, s:ARGOPT, s:DFLALL, s:TRLBAR),
      \  },
      \  {
      \    'command':'vglobal',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:DFLALL, s:CMDWIN),
      \  },
      \  {
      \    'command':'version',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'verbose',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:RANGE, s:NOTADR, s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'vertical',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM),
      \  },
      \  {
      \    'command':'visual',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'view',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'vimgrep',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'vimgrepadd',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:TRLBAR, s:XFILE),
      \  },
      \  {
      \    'command':'viusage',
      \    'flags':wildsearch#getcompletion#or(s:TRLBAR),
      \  },
      \  {
      \    'command':'vmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'vmapclear',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'vmenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'vnoremap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'vnew',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'vnoremenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'vsplit',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:RANGE, s:NOTADR, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'vunmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'vunmenu',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'write',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:BANG, s:FILE1, s:ARGOPT, s:DFLALL, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'wNext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:NOTADR, s:BANG, s:FILE1, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'wall',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'while',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTRLCOM, s:SBOXOK, s:CMDWIN),
      \  },
      \  {
      \    'command':'winsize',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NEEDARG, s:TRLBAR),
      \  },
      \  {
      \    'command':'wincmd',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:WORD1, s:RANGE, s:NOTADR, s:CMDWIN),
      \  },
      \  {
      \    'command':'windo',
      \    'flags':wildsearch#getcompletion#or(s:NEEDARG, s:EXTRA, s:NOTRLCOM, s:RANGE, s:NOTADR, s:DFLALL),
      \  },
      \  {
      \    'command':'winpos',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'wnext',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:FILE1, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'wprevious',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:BANG, s:FILE1, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'wq',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:BANG, s:FILE1, s:ARGOPT, s:DFLALL, s:TRLBAR),
      \  },
      \  {
      \    'command':'wqall',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:ARGOPT, s:DFLALL, s:TRLBAR),
      \  },
      \  {
      \    'command':'wsverb',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:NOTADR, s:NEEDARG),
      \  },
      \  {
      \    'command':'wshada',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'wundo',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:NEEDARG, s:FILE1),
      \  },
      \  {
      \    'command':'wviminfo',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:FILE1, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'xit',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:BANG, s:FILE1, s:ARGOPT, s:DFLALL, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'xall',
      \    'flags':wildsearch#getcompletion#or(s:BANG, s:TRLBAR),
      \  },
      \  {
      \    'command':'xmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'xmapclear',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'xmenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'xnoremap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'xnoremenu',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:NOTADR, s:ZEROR, s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'xunmap',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'xunmenu',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:TRLBAR, s:NOTRLCOM, s:USECTRLV, s:CMDWIN),
      \  },
      \  {
      \    'command':'yank',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:REGSTR, s:COUNT, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'z',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:EXFLAGS, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'!',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:BANG, s:FILES, s:CMDWIN),
      \  },
      \  {
      \    'command':'#',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'&',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'<',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':':',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:TRLBAR, s:DFLALL, s:EXFLAGS, s:CMDWIN),
      \  },
      \  {
      \    'command':'>',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:COUNT, s:EXFLAGS, s:TRLBAR, s:CMDWIN, s:MODIFY),
      \  },
      \  {
      \    'command':'@',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:TRLBAR, s:CMDWIN),
      \  },
      \  {
      \    'command':'Next',
      \    'flags':wildsearch#getcompletion#or(s:EXTRA, s:RANGE, s:NOTADR, s:COUNT, s:BANG, s:EDITCMD, s:ARGOPT, s:TRLBAR),
      \  },
      \  {
      \    'command':'~',
      \    'flags':wildsearch#getcompletion#or(s:RANGE, s:WHOLEFOLD, s:EXTRA, s:CMDWIN, s:MODIFY),
      \  },
      \]

let s:command_map = {}

for s:cmd in s:commands
  let s:command_map[s:cmd.command] = s:cmd
endfor
