require 'ostruct'

class StateMachine
  class InvalidTransitionException < StandardError; end

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
    @current_line = line

    case line
    when /\ABovada Hand #/
      transition_to(:create_hand)
    when /\ASeat (\d+)/
      transition_to(:create_player)
    end
  end

  private

  def changed_to_create_hand
    @current_hand = create_hand(@current_line)
    @hands << @current_hand
  end

  def changed_to_create_player
    @current_hand.players ||= []

    @current_hand.players << OpenStruct.new.tap do |player|
      @current_line.match(/\ASeat (\d+)/)
      player.name = "Seat #{$1}"
      player.position = @current_line.match(/: ([A-z ]+)/).captures.first.strip

      if player.position =~ /\[ME\]/
        player.position.gsub!(/\[ME\]/, '')
        player.position.strip!
        player.me = true
      end

      raw_stack = @current_line.match(/\(\$([0-9\.]+) in chips\)/).captures.first
      player.stack = (raw_stack.to_f * 100).to_i
    end
  end

  def create_hand(line)
    OpenStruct.new.tap do |hand|
      hand.id, hand.table_id, hand.time =
        line.match(/#(\d+) TBL#(\d+).*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/).captures
    end
  end

  def transition_to(new_state)
    if TRANSITIONS[@state].include?(new_state)
      @state = new_state
      send("changed_to_#{@state}")
    else
      raise InvalidTransitionException, "Invalid transition from #{@state} to #{new_state}"
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
  begin
    sm.event(line)
  rescue StateMachine::InvalidTransitionException
    break
  end
end

require 'pry'; binding.pry
