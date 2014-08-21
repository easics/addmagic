function! AddMagic()
  let l:basename=expand("%:t:r")
  let l:dirname=expand("%:h")
  if l:dirname == ""
    let l:dirname = '.'
  endif
  let l:headerfile=l:dirname . "/" . l:basename . ".h"
  let l:sourcefile=l:dirname . "/" . l:basename . ".C"
  let l:classname=system("sed -e '/^class.*[^;]$/!d' " . l:headerfile)
  let l:classname=substitute(l:classname, '\v^class *(\k+).*', '\1', "")
  let l:sedoutput=system("sed -f ~/.vim/bundle/addmagic/plugin/magic.sed " . l:headerfile)
  let l:linenumber=1
  let l:methods_in_sourcefile='@'
  while l:linenumber < line('$')
    let l:the_match=matchstr(getline(l:linenumber),
                           \ l:classname."::.*(")
    if l:the_match != ""
      let l:the_match=substitute(l:the_match, "^".l:classname."::", "", "")
      let l:the_match=substitute(l:the_match, "($", "", "")
      let l:methods_in_sourcefile=l:methods_in_sourcefile.l:the_match."@"
    endif
    let l:linenumber = l:linenumber + 1
  endwhile

  let l:to_be_added=''
  let l:sedoutput=substitute(l:sedoutput, "\n", '@', 'g')
  let l:sedline=matchstr(l:sedoutput, "^[^@]*")
  while l:sedline != ''
    " remove trailing spaces
    let l:methodname=substitute(l:sedline, " *$", '', '')
    " remove return type (if any)
    let l:methodname=substitute(l:methodname, "[^(]* ", "", '')
    " remove argument list (if any left)
    let l:methodname=substitute(l:methodname, "(.*", "", '')
    if l:methods_in_sourcefile !~ escape("@".l:methodname."@", '~')
      let l:sedline=substitute(l:sedline, '\(\I\i*(\)', l:classname.'::\1', "")
      let l:sedline=substitute(l:sedline, 'virtual *', '', '')
      let l:sedline=substitute(l:sedline, ' *@$', '', '')
      let l:sedline=substitute(l:sedline, ';$', "@{@}@@", '')
      let l:to_be_added=l:to_be_added.l:sedline
    endif
    let l:sedoutput=substitute(l:sedoutput, "^[^@]*@", "", "")
    let l:sedline=matchstr(l:sedoutput, "^[^@]*")
  endwhile

  let l:append_line=matchstr(l:to_be_added, "^[^@]*")
  let l:lineincrement=0
  while strlen(l:to_be_added)
    call append(line('.') + l:lineincrement, l:append_line)
    let l:lineincrement=l:lineincrement + 1
    let l:to_be_added=substitute(l:to_be_added, "^[^@]*@", "", "")
    let l:append_line=matchstr(l:to_be_added, "^[^@]*")
  endwhile
endfunction

function! AddMagicAri()
  let l:message=system("~/.vim/bundle/addmagic/plugin/complete_ari.sh " . expand("%:p")." 2>&1")
  let l:messagesplit=split(l:message, "\n")
  for l:line in l:messagesplit
    echoerr l:line
  endfor
  if v:shell_error
    return
  endif
  normal mxG
  :r /tmp/ari_append
  !rm /tmp/ari_append
  normal `x
endfunction

autocmd FileType cpp nmap <F7> :call AddMagic()
autocmd FileType ari nmap <F7> :call AddMagicAri()
