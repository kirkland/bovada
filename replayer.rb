require "curses"
include Curses

init_screen

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
