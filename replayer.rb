require "curses"
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

puts cells.inspect
exit

player_positions = {
  'Player 1' => [5, (cols / 2) - 8]
}

# Height, width, y, x
#win = Window.new(5, 5, 0, 0)
#win.box('|', '-')
#win.setpos(1, 1)
#win.addstr("hello")
#win.refresh
#win.getch
#win.close

player_positions.each do |name, player_position|
  win = Window.new(5, 16, *player_position)
  win.box('|', '-')
  win.setpos(1, 4)
  win.addstr(name)
  win.refresh
  win.getch
  win.close
end

# Man file says this is necessary, yet it doesn't exist here
# endwin
