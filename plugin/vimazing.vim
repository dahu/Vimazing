" ============================================================================
" File:   vimazing - A typing trainer, Vim style.
" Description: A game to train the normal mode movements in Vim
" Authors:     Barry Arthur <barry dot arthur at gmail dot com>
"              Israel Chauca <israelchauca at gmail dot com>
" Last Change: 14 August, 2010
" Website:     http://github.com/dahu/VimLint
" Credits:
" * #vim user, brah, gave me the idea by asking for it one day
" * maze algorithm taken from: http://www.sulaco.co.za/maze.htm
"
" See vimazing.txt for help.  This can be accessed by doing:
"
" :helptags ~/.vim/doc
" :help vimazing
"
" Licensed under the same terms as Vim itself.
" ============================================================================
let s:Vimazing_version = '0.0.2'  " alpha, playable

" History:{{{1
" v.0.0.2 changes:
" * using Vim's quickload feature. (Raimondi)
" v.0.0.1 initial release:
" * playable with increasing level difficulty
"
" Quickloader:{{{1
" Create the command and wait until the rest is needed (as per 41.14).
if !exists("s:did_load")
  command! -nargs=0 Vimazing call Vimazing()
  let s:did_load = 1
  exe 'au FuncUndefined Vimazing* source ' . expand('<sfile>')
  finish
endif
"
" Vimscript setup {{{1
let s:old_cpo = &cpo
set cpo&vim

" Configuration Options {{{1
let s:size = 10 " XXX easier to start at that size.
let s:lifes = 3
let s:time = 120

"let s:maze_height = 10
" Configuration Options }}}1
" Support Classes {{{1
" George Marsaglia's Multiply-with-carry Random Number Generator {{{2
let s:m_w = matchstr(tempname(), '\d\+') * getpid()
let s:m_z = localtime()

" sledge hammer to crack a nut?
" also... not sure of the wisdom of generating a full 32-bit RN here
" and then using abs() on the sucker. But it'll do for now...
function! RandomNumber()
  let s:m_z = s:m_z + (s:m_z / 4)
  let s:m_w = s:m_w + (s:m_w / 4)
  return abs((s:m_z) + s:m_w)      " 32-bit result
endfunction
" end RNG }}}2

" Cell class {{{2
" height and width are coordinates withing a grid, resulting in a single cell
function! Cell(height, width)
  let c = {}
  let c.h_val = a:height
  let c.w_val = a:width
  function c.set_w(v) dict
    let self.w_val = a:v
    return self.w_val
  endfunction
  function c.set_h(v) dict
    let self.h_val = a:v
    return self.h_val
  endfunction
  function c.h() dict
    return self.h_val
  endfunction
  function c.w() dict
    return self.w_val
  endfunction
  function c.add(ary) dict
    let self.h_val += a:ary[0]
    let self.w_val += a:ary[1]
    return self
  endfunction
  function c.to_s()
    return '[' . self.h_val . ', ' . self.w_val . ']'
  endfunction
  " TESTS
  function c.TestCellAdd()
    let cell = Cell(1, 1)
    let neighbours = [[1,0], [0,-1], [-1,0], [0,1]]
    let expecteds  = [[2,1], [1,0],  [0,1],  [1,2]]
    let index = 0
    while index < 4
      let newcell = copy(cell).add(neighbours[index])
      let expected = expecteds[index]
      if newcell.h() != expected[0] && newcell.w() != expected[1]
        echo "Cell.TestCellAdd : Failed adding " . join(neighbours[index], ',') . ' ' . newcell.to_s()
      endif
      let index += 1
    endwhile
  endfunction
  return c
endfunction
" end Cell class }}}2
" end Support classes }}}1
" Maze class {{{1
"
function! NewMaze(height, width)
  let maze = {}
  let maze.grid = []
  let maze.opened_cells = []
  let maze.height = a:height
  let maze.width = a:width

  " create an 'empty' maze (full of # characters)
  function maze.Setup() dict
    " TODO: Come back here and try the map(repeat( solution later...
    "let baz=map(repeat( [ [1,2,3] ], 3), 'copy(v:val)')
    let self.grid = []
    for n in repeat([0], self.height)
      call add(self.grid, repeat(['#'], self.width))
    endfor
  endfunction

  " Create a path through the maze to be followed
  function maze.MakePath() dict
    " pick a random cell inside the grid (not on the outside walls)
    let self.cell = self.ChooseStartingCell()
    "let self.cell = Cell(self.height - 2, self.width - 2) " XXX: TESTING
    let result = 0
    call self.OpenCell()
    while len(self.opened_cells) > 0
      let result = self.ChooseNextCell()
      while result != -1
        call self.OpenCell()
        let result = self.ChooseNextCell()
      endwhile
      let self.cell = remove(self.opened_cells, 0)
    endwhile
  endfunction

  " naive version to begin with - just crawls in from top-left corner for Start
  " and back from bottom right corner for End
  " TODO: Needs DRYing
  function maze.StartAndEnd() dict
    let cell = Cell(1, 1)
    let done_start = 0
    while ! done_start
      if self.grid[cell.h()][cell.w()] == ' '
        let self.grid[cell.h() - 1][cell.w()] = 'X'
        let done_start = 1
      endif
      call cell.add([0,1])
    endwhile
    let cell = Cell(self.height - 2, self.width - 2)
    let done_end = 0
    while ! done_end
      if self.grid[cell.h()][cell.w()] == ' '
        let self.grid[cell.h() + 1][cell.w()] = '+'
        let done_end = 1
      endif
      call cell.add([0,-1])
    endwhile
  endfunction

  " Clear a single cell in the maze
  function maze.OpenCell(...) dict
    let marker = ' '
    if a:0 == 1
      let marker = a:1
    endif
    call add(self.opened_cells, self.cell)
    let self.grid[self.cell.h()][self.cell.w()] = marker
  endfunction

  " Pick a random internal (not along the walls) grid cell
  function maze.ChooseStartingCell() dict
    return Cell( 1 + (RandomNumber() % (self.height - 2)), 1 + (RandomNumber() % (self.width - 2)))
  endfunction

  function maze.ValidInnerCell(cell) dict
    " Rule: x > 0 && x < (self.width - 1)
    "       y > 0 && y < (self.height - 1)
    " Rule B: No square with >1 open neighbour (checked elsewhere now)
    let rule_a = (a:cell.h() > 0) && (a:cell.h() < (self.height - 1)) &&
          \ (a:cell.w() > 0) && (a:cell.w() < (self.width - 1))
    "" XXX Debugging:
    "if ! rule_a
    "echo "failed rule a: " . a:cell.h() . ',' . a:cell.w()
    "endif
    return rule_a
  endfunction

  " Choose next cell to open along the path
  function maze.ChooseNextCell() dict
    " as always, the grid and cells within are accessed as [height,width]
    let neighbours = [[1,0], [0,-1], [-1,0], [0,1]]
    let choice = RandomNumber() % 4
    let done = 0
    let tries = {}
    while ! done && (len(tries) < 4)
      let tries[choice] = 1
      let newcell = copy(self.cell).add(neighbours[choice])
      if self.ValidInnerCell(newcell) && (self.CountOpenNeighbours(newcell) <= 1)
        let self.cell = newcell
        let done = 1
      elseif len(tries) < 4
        let choice = RandomNumber() % 4
        while has_key(tries, choice)
          "let choice = (choice + 1) % 4
          let choice = RandomNumber() % 4
        endwhile
      else
        let tries.end = 1
        break
      end
    endwhile
    if len(tries) == 5
      " no further steps can be taken along current path
      return -1
    else
      return 0
    endif
  endfunction

  " number of open neighbours that a potential cell has.
  " if this returns > 1 then 'cell' is not a valid move
  function maze.CountOpenNeighbours(cell) dict
    let cnt = 0
    let neighbours = [[1,0], [0,-1], [-1,0], [0,1]]
    let index = 0
    while index < 4
      let newcell = copy(a:cell).add(neighbours[index])
      if self.ValidInnerCell(newcell)
        let cnt += (self.grid[newcell.h()][newcell.w()] == ' ' ? 1 : 0)
      endif
      let index += 1
    endwhile
    return cnt
  endfunction

  " print the grid, ready for playing
  function maze.Print()
    "call append('$',[''])
    call map(copy(self.grid), "append('$', join(v:val, ''))")
  endfunction

  " TEST support{{{2
  function maze.TestOpen(cell) dict
    let self.grid[a:cell.h()][a:cell.w()] = ' '
  endfunction

  " Test a cell for number of open neighbours
  function maze.TestCountOpenNeighbours() dict
    let f = 'maze.TestCountOpenNeighbours() : '
    let t = NewMaze(3,3)
    call t.Setup()
    call t.TestOpen(Cell(1,1))
    let p = Cell(1,1)
    " above
    call t.TestOpen(Cell(0,1))
    let c = t.CountOpenNeighbours(p)
    if c != 1
      echo f . "Failed: above"
    endif
    " left
    call t.TestOpen(Cell(1,0))
    let c = t.CountOpenNeighbours(p)
    if c != 2
      echo f . "Failed: left"
    endif
    " bottom
    call t.TestOpen(Cell(2,1))
    let c = t.CountOpenNeighbours(p)
    if c != 3
      echo f . "Failed: bottom"
    endif
    " right
    call t.TestOpen(Cell(1,2))
    let c = t.CountOpenNeighbours(p)
    if c != 4
      echo f . "Failed: right"
    endif
  endfunction
  " end Tests }}}2

  return maze
endfunction " end Maze class }}}1

let s:root = expand('<sfile>:h:h')

"
" Vimaze class {{{1
function! NewVimaze(lifes, time, size)
  let vimaze = {}
  let vimaze.lifes = a:lifes
  let vimaze.time  = a:time
  let vimaze.size  = a:size
  let vimaze.rules = {'X':'start', '+':'end', ' ':'empty', '#':'wall', 'out':'out'}
  let vimaze.paused = 0
  let vimaze.pos = []

  function vimaze.Setup() dict
    let self.rem_lifes = self.lifes
    let self.rem_time = self.time
    let self.prev_time = 0
    let self.size = self.size
    let self.maze = NewMaze(self.size, self.size * 2)
    call self.maze.Setup()
    call self.maze.MakePath()
    call self.maze.StartAndEnd()
    call self.Print('Press <Space> to start.')
    " just for now XXX you need pathogen :p
    "exec 'source '.s:root.'/syntax/vimazing.vim'
    call self.ResetCursor()
    let self.prev_time = localtime()
    " Disable cheating mouse:
    set mouse=
    "augroup Vimazing
      "au!
    "augroup END
    call self.ClearAutoCommands()
    noremap <buffer> <space> :silent call b:vimaze.Pause()<CR><Esc>
      for key in ["<Left>", "<Right>", "<Up>", "<Down>", "<CR>", "a", "A", "i", "I", "o", "O"]
        execute "silent! unmap <buffer> ".key
      endfor
    silent $s/^.*$/Press <Space> to start./
    exec 'silent 3;+'. (self.size - 1).'s/[^X]/#/g'
    let self.paused = 1
    call self.ResetCursor()
  endfunction

  function vimaze.ClearAutoCommands()
    augroup Vimazing
      au!
    augroup END
    call self.SyntaxHighlightAutoCommands()
  endfunction

  function vimaze.SyntaxHighlightAutoCommands()
    augroup Vimazing
      au BufEnter <buffer> exec 'source '.s:root.'/syntax/vimazing.vim'
      au BufLeave <buffer> exec 'colors '.b:colors_name
    augroup END
  endfunction

  function vimaze.SetupAutoCommands()
    augroup Vimazing
      au!
      au CursorMoved,CursorHold <buffer>
            \ if &filetype == 'vimazing' |
            \   call b:vimaze.Update() |
            \ endif
    augroup END
    call self.SyntaxHighlightAutoCommands()
  endfunction

  function vimaze.Update() dict
    let msg = []
    let self.rem_time += self.prev_time - localtime()
    let self.prev_time = localtime()
    if self.rem_time <= 0
      call self.Setup()
      call add(msg, 'You lost on time! Try again.')
    endif
    let key = getline('.')[col('.')-1]
    if has_key(self.rules, key)
      let current = self.rules[key]
      if current == 'start'
        call add(msg, 'Start!')
      elseif current == 'end'
        let  self.size += 5
        let self.time += 15
        call self.Setup()
        call add(msg, 'You finished! Now attack this one.')
      elseif current == "empty"
        call add(msg, 'Good')
      elseif current == 'wall'
        let self.rem_lifes -= 1
        call add(msg, 'Too bad! You hit the wall.')
        call self.ResetCursor()
      elseif current == 'out'
      else
        call add(msg, 'If you see this, the world''s about to end, save yourself!')
      endif
    elseif key != ''
      echoe 'That shouldn''t be there!: '.key.', pos: ('.line('.').','.col('.').')'
      call self.ResetCursor()
    else
      call add(msg, 'You should go the other way.')
      call self.ResetCursor()
    endif
    if self.rem_lifes < 0
      call self.Setup()
      call add(msg, 'You lost all your lives! Try again.')
    endif
    call self.SetHeader()
    echo join(msg, "\n")
  endfunction

  function vimaze.Pause() dict
    noremap <buffer> <space> :silent call b:vimaze.Pause()<CR><Esc>
    if self.paused
      let self.prev_time = localtime()
      call self.Print('Press <Space> to pause.')
      "augroup Vimazing
        "au!
        "au CursorMoved,CursorHold *
              "\ if &filetype == 'vimazing' |
              "\   call b:vimaze.Update() |
              "\ endif
      "augroup END
      call self.SetupAutoCommands()
      for key in ["<Left>", "<Right>", "<Up>", "<Down>", "<CR>", "a", "A", "i", "I", "o", "O"]
        execute "noremap <buffer> ".key." <Nop>"
      endfor
      call setpos('.', self.pos)
      let self.paused = 0
      echo 'Game paused.'
    else
      let self.pos = getpos('.')
      "augroup Vimazing
        "au!
      "augroup END
      call self.ClearAutoCommands()
      for key in ["<Left>", "<Right>", "<Up>", "<Down>", "<CR>", "a", "A", "i", "I", "o", "O"]
        execute "unmap <buffer> ".key
      endfor
      call self.Print('Press <Space> to pause.')
      exec 'silent 3;+'. (self.size - 1).'s/[^X]/#/g'
      let self.paused = 1
      $s/Press.*$/Press <Space> to continue./
      call self.ResetCursor()
      echo 'Go ahead!'
    endif
  endfunction

  function vimaze.Print(msg) dict
    silent %d
    call self.maze.Print()
    call append(0,'')
    call self.SetHeader()
    call append(line('$'), [a:msg])
  endfunction

  function vimaze.ResetCursor() dict
    call search('X', 'cw')
    nohlsearch
  endfunction

  function vimaze.SetHeader() dict
    call setline(1, 'Lifes: '.self.rem_lifes.'   Timer: '.(self.rem_time / 60).':'.(self.rem_time % 60 > 9 ? self.rem_time % 60 : '0' . self.rem_time % 60))
    set buftype=nofile
  endfunction

  call vimaze.Setup()
  return vimaze
endfunction " end Vimaze class }}}1

" Tests {{{1
function! TestVimazing()
  let test = NewMaze(0,0)
  call test.TestCountOpenNeighbours()

  let test = Cell(0,0)
  call test.TestCellAdd()
endfunction " end Tests }}}1
"
" Public Interface {{{1
function! Vimazing()
  if &filetype == 'vimazing'
    normal! ggdG
  else
    new
    only
    let b:colors_name = 'default'
    if exists('g:colors_name')
      let b:colors_name = g:colors_name
    endif
    set ft=vimazing
  endif
  let b:vimaze = NewVimaze(s:lifes, s:time, s:size)
endfunction

" end Public Interface }}}1
"
" Teardown:{{{1
"reset &cpo back to users setting
let &cpo = s:old_cpo

" vim: set sw=2 sts=2 et fdm=marker:

finish
