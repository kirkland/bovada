require 'ostruct'

class StateMachine
  class InvalidTransitionException < StandardError; end

  attr_reader :hands

  TRANSITIONS = {
    start: [:create_hand],
    create_hand: [:create_player],
    create_player: [:create_player, :post_blind],
    post_blind: [:post_blind, :deal_hand],
    deal_hand: [:deal_hand, :action, :showdown],
    action: [:action]
  }

  STATES = TRANSITIONS.keys

  def initialize
    @state = :start
    @hands = []
    @current_hand = nil
  end

  def event(line)
    @current_line = line

    case @current_line
    when /\ABovada Hand #/
      transition_to(:create_hand)
    when /\ASeat (\d+)/
      transition_to(:create_player)
    when /\ADealer : Set dealer\/Bring in spot/
      # no-op
    when /Ante\/Small Blind/, /Big blind\/Bring in/
      transition_to(:post_blind)
    when /Card dealt to a spot/
      transition_to(:deal_hand)
    when /\*\*\* HOLE CARDS/
      # no-op
    when / : Folds/
      transition_to(:action)
    else
      raise InvalidTransitionException, 'Line did not match a pattern'
    end
  end

  private

  def changed_to_create_hand
    @current_hand = create_hand
    @hands << @current_hand
  end

  def changed_to_create_player
    @current_hand.players ||= []

    @current_hand.players << OpenStruct.new.tap do |player|
      @current_line.match(/\ASeat (\d+)/)
      player.name = "Seat #{$1}"
      raw_player_position = @current_line.match(/: ([A-z ]+)/).captures.first
      player.position = cleanup_player_position(raw_player_position)

      if raw_player_position =~ /\[ME\]/
        player.me = true
      end

      raw_stack = @current_line.match(/\(\$([0-9\.]+) in chips\)/).captures.first
      player.stack = (raw_stack.to_f * 100).to_i
    end
  end

  def changed_to_post_blind
    @current_betting_round ||= []

    @current_betting_round << OpenStruct.new.tap do |action|
      action.type = :blind

      raw_stack = @current_line.match(/\$([\d\.]+)/).captures.first
      action.bet_amount = (raw_stack.to_f * 100).to_i

      if @current_line =~ /\ASmall Blind.*\$([\d\.]+)/
        action.player = @current_hand.players.detect { |x| x.position == 'Small Blind' }
      else
        action.player = @current_hand.players.detect { |x| x.position == 'Big Blind' }
      end
    end
  end

  def changed_to_deal_hand
    player_position, hole_cards = @current_line.
      match(/\A([A-Za-z \+\d\[\]]+) : Card dealt to a spot \[(.*)\]/).captures

    player = @current_hand.players.detect { |x| x.position == cleanup_player_position(player_position) }
    player.hole_cards = hole_cards
  end

  def changed_to_action
    if @current_line =~ /Folds/
      @current_betting_round << OpenStruct.new.tap do |action|
        player_position = @current_line.match(/\A(.*) :/).captures.first

        action.type = :fold
        action.player = @current_hand.players.detect { |x| x.position == player_position }
      end
    end
  end

  def cleanup_player_position(name)
    name.gsub(/\[ME\]/, '').strip
  end

  def create_hand
    OpenStruct.new.tap do |hand|
      hand.id, hand.table_id, hand.time =
        @current_line.match(/#(\d+) TBL#(\d+).*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/).captures

      hand.preflop_actions = []
      @current_betting_round = hand.preflop_actions
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
    File.read(filename).split("\r\n").each_with_index do |line, line_number|
      # Remove UTF-16 byte order mark
      line.sub!(/\ufeff/, '')
      yield line, filename, line_number
    end
  end
end

sm = StateMachine.new

each_line do |line, filename, line_number|
  begin
    sm.event(line)
  rescue StateMachine::InvalidTransitionException => e
    puts "Stopping on invalid transition in file: #{filename}, line #{line_number}, error: #{e.message}"
    puts "Content: #{line}"
    break
  end
end

require 'pry'; binding.pry
