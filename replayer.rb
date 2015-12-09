require "curses"
require 'ap'

include Curses

init_screen

# The entire screen is filled up by cells. A cell is determined by:
# y: Row offset from TOP.
# x: Column offset from left.

# All cells have the same height and width

cell_height = lines / 3
cell_width = cols / 4

cells = 4.times.collect do |column_index|
  3.times.collect do |row_index|
    [cell_height * row_index, cell_width * column_index]
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

def add_name(name, win, cell_width)
  center = cell_width / 2
  win.setpos(1, center - name.length / 2)
  win.addstr(name)
end

def add_stack(amount, win, cell_width, cell_height)
  cents = amount % 100
  dollars = amount / 100
  amount_string = "$#{dollars}.#{cents}"

  center = cell_width / 2
  win.setpos(3, center - amount_string.length / 2)
  win.addstr(amount_string)
end

player_cell_indexes.each do |name, player_position|
  offsets = cells[player_position[0]][player_position[1]]

  win = Window.new(cell_height, cell_width, *offsets)
  win.box('|', '-')
  add_name(name, win, cell_width)
  add_stack(rand(1000), win, cell_width, cell_height)
  win.refresh
  win.getch
  win.close
end
