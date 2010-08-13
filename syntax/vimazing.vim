" Vim syntax file
" Language:     Vimazing
" Maintainer:   Barry Arthur <barry.arthur at gmail dot org>

"if exists("b:current_syntax")
"  finish
"endif

syn sync fromstart

set guicursor=a:blinkon0

hi def vimazingWall      ctermfg=Black ctermbg=Black guifg=Black guibg=Black
hi def vimazingOpenSpace ctermfg=White ctermbg=White guifg=White guibg=White
hi Cursor                guifg=NONE guibg=Magenta
hi lCursor               guifg=NONE guibg=Magenta
"hi def vimazingObject    ctermfg=LightBlue ctermbg=White guifg=LightBlue guibg=White
hi def vimazingObject    ctermfg=White ctermbg=LightBlue guifg=White guibg=LightBlue
hi def vimazingText      ctermfg=DarkBlue ctermbg=White guifg=DarkBlue guibg=White

syn match vimazingText +^[^#].\++

syn region vimazingMaze start=+^#+ end=+\n\ze[^#]+ contains=vimazingObject,vimazingWall,vimazingOpenSpace
syn match vimazingWall +#+ contained
"syn match vimazingOpenSpace + + contained
syn match vimazingObject +[^ #]+ contained

let b:current_syntax = "vimazing"

" vim:set sw=2:
