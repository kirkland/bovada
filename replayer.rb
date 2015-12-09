require "curses"
require 'ap'

include Curses

init_screen

# The entire screen is filled up by cells. A cell is determined by:
# x: Column offset from left.
# y: Row offset from TOP.

# All cells have the same height and width

cell_width = cols / 4
cell_height = lines / 3

cells = 3.times.collect do |row_index|
  4.times.collect do |column_index|
    {
      x: cell_width * column_index,
      y: cell_height * row_index
    }
  end
end

player_cell_indexes = {
  'Player 1' => [1, 0],
  'Player 2' => [2, 0],
  'Player 3' => [3, 1],
  'Player 4' => [2, 2],
  'Player 5' => [1, 2],
  'Player 6' => [0, 1]
}

# Height, width, y, x
#win = Window.new(5, 5, 0, 0)
#win.box('|', '-')
#win.setpos(1, 1)
#win.addstr("hello")
#win.refresh
#win.getch
#win.close

player_cell_indexes.each do |name, player_position|
  x_offset = cells[player_position[1]][player_position[0]][:x]
  y_offset = cells[player_position[1]][player_position[0]][:y]

  win = Window.new(cell_height, cell_width, y_offset, x_offset)
  win.box('|', '-')
  win.setpos(1, 4)
  win.addstr(name)
  win.refresh
  win.getch
  win.close
end

# Man file says this is necessary, yet it doesn't exist here
# endwin
