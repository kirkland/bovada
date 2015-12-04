require 'ostruct'

class StateMachine
  class InvalidTransition < StandardError; end

  attr_reader :hands

  TRANSITIONS = {
    start: [:create_hand],
    create_hand: [:create_player],
    create_player: [:create_player, :post_blind],
    post_blind: [:post_blind, :deal_hand],
    deal_hand: [:deal_hand, :action],
    action: [:action, :showdown]
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
      raise InvalidTransition, 'Line did not match a pattern'
    end
  end

  private

  def changed_to_create_hand
    @current_hand = OpenStruct.new.tap do |hand|
      hand.id, hand.table_id, hand.time =
        @current_line.match(/#(\d+) TBL#(\d+).*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/).captures

      hand.preflop_actions = []
      @current_betting_round = hand.preflop_actions
    end

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

      player.stack = extract_amount
    end
  end

  def changed_to_post_blind
    @current_betting_round ||= []

    @current_betting_round << OpenStruct.new.tap do |action|
      action.type = :blind
      action.bet_amount = extract_amount

      if @current_line =~ /\ASmall Blind.*\$([\d\.]+)/
        action.player = player_in_position('Small Blind')
      else
        action.player = player_in_position('Big Blind')
      end
    end
  end

  def changed_to_deal_hand
    player_position, hole_cards = @current_line.
      match(/\A([A-Za-z \+\d\[\]]+) : Card dealt to a spot \[(.*)\]/).captures

    player = player_in_position(player_position)
    player.hole_cards = hole_cards
  end

  def changed_to_action
    if @current_line =~ /Folds/
      @current_betting_round << OpenStruct.new.tap do |action|
        player_position = @current_line.match(/\A(.*) :/).captures.first

        action.type = :fold
        action.player = player_in_position(player_position)
      end
    end
  end

  def cleanup_player_position(name)
    name.gsub(/\[ME\]/, '').strip
  end

  def transition_to(new_state)
    if TRANSITIONS[@state].include?(new_state)
      @state = new_state
      send("changed_to_#{@state}")
    else
      raise InvalidTransition, "Invalid transition from #{@state} to #{new_state}"
    end
  end

  def extract_amount
    if @current_line.count('$') > 1
      raise "Uh oh, I don't know which amount to extract from #{@current_line}"
    else
      raw_stack = @current_line.match(/\$([0-9\.]+)/).captures.first
      (raw_stack.to_f * 100).to_i
    end
  end

  def player_in_position(position)
    @current_hand.players.detect { |x| x.position == cleanup_player_position(position) }
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
  rescue StateMachine::InvalidTransition => e
    puts "Stopping on invalid transition in file: #{filename}, line #{line_number}, error: #{e.message}"
    puts "Content: #{line}"
    break
  end
end

require 'pry'; binding.pry
