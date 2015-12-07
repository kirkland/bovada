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
    action: [:action, :showdown, :deal_flop, :deal_turn, :deal_river],
    deal_flop: [:action, :deal_turn, :deal_river],
    deal_turn: [:action, :deal_river],
    deal_river: [:action, :showdown],
    showdown: [:showdown, :create_hand]
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
    when /\ABovada Hand #/, /\ASeat\+Bovada Hand/
      transition_to(:create_hand)
    when /\ASeat (\d+)/
      transition_to(:create_player)
    when / : Set dealer\/Bring in spot/
      # no-op
    when /Ante\/Small Blind/, /Big blind\/Bring in/, /Posts chip/
      transition_to(:post_blind)
    when /Card dealt to a spot/
      transition_to(:deal_hand)
    when /\A\*\*\* HOLE CARDS/
      # no-op
    when / : Folds/, / : Calls/, / : Checks/, / : Bets/, / : Raises/, /: All-in/
      transition_to(:action)
    when /\A\*\*\* FLOP/
      transition_to(:deal_flop)
    when /\A\*\*\* TURN/
      transition_to(:deal_turn)
    when /\A\*\*\* RIVER/
      transition_to(:deal_river)
    when /Does not show/, /Hand result/, /Return uncalled portion/, /Showdown/, /Mucks/
      transition_to(:showdown)
    when /Table enter user/, /Seat sit down/
      # no-op
    when /\A\*\*\* SUMMARY/, /\ASeat\+\d/, /Board/, /Total Pot/, /\A\z/, /Table deposit/,
         /Seat stand/, /Table leave user/, /Seat sit out/, /Seat re-join/
      # no-op
    else
      raise InvalidTransition, 'Line did not match a pattern'
    end
  end

  private

  # Transition functions

  def transition_to(new_state)
    if TRANSITIONS[@state].include?(new_state)
      @state = new_state
      send("changed_to_#{@state}")
    else
      raise InvalidTransition, "Invalid transition from #{@state} to #{new_state}"
    end
  end

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
      raw_player_position = @current_line.match(/: ([A-z +\d]+)/).captures.first
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
      action.player = current_player
    end
  end

  def changed_to_deal_hand
    hole_cards = @current_line.match(/.*: Card dealt to a spot \[(.*)\]/).captures.first
    current_player.hole_cards = hole_cards
  end

  def changed_to_action
    @current_betting_round << OpenStruct.new.tap do |action|
      action.player = current_player

      action.type = case @current_line
      when /Folds/
        action.type = :fold
      when /Calls/
        action.type = :call
      when /Bets/
        action.type = :bet
      when /Checks/
        action.type = :check
      when /Raises/
        action.type = :raise
      when /All-in\(raise\)/
        action.type = :raise
      when /All-in/
        # NOTE: This could also be a call
        action.type = :bet
      end
    end
  end

  def changed_to_deal_flop
    cards = @current_line.match(/\[([A-Za-z\d]{2}) ([A-Za-z\d]{2}) ([A-Za-z\d]{2})\]/).captures
    @current_hand.board = cards
  end

  def changed_to_deal_turn
    card = @current_line.match(/\[([A-Za-z\d]{2})\]/).captures.first
    @current_hand.board << card
  end

  def changed_to_deal_river
    card = @current_line.match(/\[([A-Za-z\d]{2})\]/).captures.first
    @current_hand.board << card
  end

  def changed_to_showdown
    # TODO: Figure out what to store for showdowns
    @current_hand.showdown_info ||= []
    @current_hand.showdown_info << @current_line
  end

  # Utility Methods

  def cleanup_player_position(name)
    name.gsub(/\[ME\]/, '').strip
  end

  # Extraction Methods

  def extract_amount
    if @current_line.count('$') > 1
      raise "Uh oh, I don't know which amount to extract from #{@current_line}"
    else
      raw_amount = @current_line.match(/\$([0-9\.]+)/).captures.first
      (raw_amount.to_f * 100).to_i
    end
  end

  def current_player
    position = @current_line.match(/\A(.*) :/).captures.first
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
