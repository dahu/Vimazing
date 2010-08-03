" ============================================================================
" File:   vimazing - A typing trainer, Vim style.
" Description: A game to train the normal mode movements in Vim
" Author:      Barry Arthur <barry.arthur at gmail dot com>
" Last Change: 22 July, 2010
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
let s:Vimazing_version = '0.0.1'  " alpha, unreleased

" TODO
" Pick (and remove) a random place in the maze.opened_cells list and start the
" path crawling again. Lather, Rinse, Repeat until opened_cells is empty - and
" the maze is complete.
" THEN, release to github as 0.0.1 - Day of Vimazement. :D

" Vimscript setup {{{1
let s:old_cpo = &cpo
set cpo&vim

" Configuration Options {{{1
let s:size = 20
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
        let self.grid[cell.h() + 1][cell.w()] = 'X'
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
      " XXX abort for now to test single path creation
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
"
" Vimaze class {{{1
function! NewVimaze()
  let vimaze = {}

  function vimaze.Setup(lifes, time, size) dict
    normal! gg"_dG
    call self.deactivate()
    let self.rules = {'X':'door', ' ':'empty', '#':'wall', 'out':'out'}
    let self.lifes = a:lifes
    let self.rem_time = a:time
    let self.start_time = 0
    let self.maze = NewMaze(a:size, a:size * 2)
    call self.maze.Setup()
    call self.maze.MakePath()
    call self.maze.StartAndEnd()
    call self.maze.Print()
    call append(0,'')
    call self.SetHeader(a:lifes, a:time)
    call cursor(1,1)
    call search('X')
    call append(line('$'), ['Press "g" to start.'])
    noremap g :call b:vimaze.activate()<CR>
  endfunction

  function vimaze.update()
    let self.rem_time += self.start_time - localtime()
    let self.start_time = localtime()
    if self.rem_time <= 0
      call self.Setup(s:lifes, s:time, s:size)
      echo 'You lost on time! Try again.'
    endif
    let key = getline('.')[col('.')-1]
    if has_key(self.rules, key)
      let current = self.rules[key]
      if current == 'door'
        echo 'Start!'
      elseif current == "empty"
        echo 'Good!'
      elseif current == 'wall'
        let self.lifes -= 1
        echo "Too bad! You hit the wall."
        call self.resetcursor()
      elseif current == 'out'
        echo "You should go the other way."
        call self.resetcursor()
      else
        echoe 'If you see this, the world is about to end, save yourself!'
      endif
    else
      echoe 'You shouldn''t be there!'
      call self.resetcursor()
    endif
    if self.lifes < 0
      call self.Setup(s:lifes, s:time, s:size)
      echo 'You lost all your lives! Try again.'
    endif
    call b:vimaze.SetHeader(self.lifes, self.rem_time)
  endfunction

  function vimaze.SetHeader(lifes, time) dict
    call setline(1, 'Lifes: '.a:lifes.'   Timer: '.(a:time / 60).':'.(a:time % 60))
    set nomodified
  endfunction

  function vimaze.activate() dict
    call self.resetcursor()
    call setline(line('$'), 'Press <Esc> to stop.')
    let self.start_time = localtime()
    augroup Vimazing
      au!
      au CursorMoved,CursorHold * call b:vimaze.update()
      au InsertEnter * exec "silent normal! \<Esc>"
    augroup END
    noremap <Esc> :call b:vimaze.deactivate()<CR>
    "for key in ["\<Left>", "\<Right>", "\<Up>", "\<Down>", "\<CR>"]
      "execute "noremap <buffer> ".key." \<Nop>"
      "echom key
    "endfor
    noremap <Left> <Nop>
    noremap <Right> <Nop>
    noremap <Up> <Nop>
    noremap <Down> <Nop>
    noremap j gj
    noremap k gk
  endfunction

  function vimaze.deactivate() dict
    silent echo line('$') > 4 ? setline(line('$'), 'Press "g" to start.') : line('.')
    augroup Vimazing
      au!
    augroup END
    unmap <Esc>
  endfunction

  function vimaze.resetcursor()
    call setpos('.', [0,3,1,0])
    normal fX

  endfunction

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
    normal! ggVGd
  else
    new
    only
    set ft=vimazing
  endif
  let b:vimaze = NewVimaze()
  call b:vimaze.Setup(s:lifes, s:time, s:size)
  set nomodified
endfunction

command! -nargs=0 Vimazing call Vimazing()

" end Public Interface }}}1
"
" Teardown:{{{1
"reset &cpo back to users setting
let &cpo = s:old_cpo

" vim: set sw=2 sts=2 et fdm=marker:

finish

