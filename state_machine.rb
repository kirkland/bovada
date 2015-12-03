require 'ostruct'

class StateMachine
  attr_reader :hands

  TRANSITIONS = {
    start: [:create_hand],
    create_hand: [:create_player],
    create_player: [:create_player, :post_blind]
  }

  STATES = TRANSITIONS.keys

  def initialize
    @state = :start
    @hands = []
    @current_hand = nil
  end

  def event(line)
    if line =~ /\ABovada Hand #/
      transition_to(:create_hand, line)
    end
  end

  private

  def changed_to_create_hand(line)
    @current_hand = create_hand(line)
    @hands << @current_hand
  end

  def create_hand(line)
    OpenStruct.new.tap do |hand|
      hand.id, hand.table_id, hand.time =
        line.match(/#(\d+) TBL#(\d+).*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/).captures
    end
  end

  def transition_to(new_state, line)
    if TRANSITIONS[@state].include?(new_state)
      @state = new_state
      send("changed_to_#{@state}", line)
    else
      raise "Invalid transition from #{@state} to #{new_state}"
    end
  end
end

def each_line
  Dir.glob('data/*').each do |filename|
    File.read(filename).split("\r\n").each do |line|
      # Remove UTF-16 byte order mark
      line.sub!(/\ufeff/, '')
      yield line
    end
  end
end

sm = StateMachine.new

each_line do |line|
  sm.event(line)
end

require 'pry'; binding.pry
