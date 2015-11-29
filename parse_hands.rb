require 'ostruct'

@hands = []

def parse_hand(hand_data)
  hand = OpenStruct.new
  hand.players = []

  hand_data.each do |line|
    case line
    when /\ABovada Hand #/
      hand.id, hand.table_id, hand.time =
        line.match(/#(\d+) TBL#(\d+).*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/).captures
    when /\ASeat (\d+)/
      hand.players << OpenStruct.new.tap do |player|
        player.name = "Seat #{$1}"
        player.position = line.match(/: ([A-z ]+)/).captures.first.strip

        if player.position =~ /\[ME\]/
          player.position.gsub!(/\[ME\]/, '')
          player.me = true
        end

        raw_stack = line.match(/\(\$([0-9\.]+) in chips\)/).captures.first
        player.stack = (raw_stack.to_f * 100).to_i
      end
    end
  end

  @hands << hand
end

def parse_file(filename)
  hand_data = []

  File.read(filename).split("\r\n").each do |line|
    # Remove UTF-16 byte order mark
    line.sub!(/\ufeff/, '')

    if hand_data.length > 0 && line =~ /\ABovada Hand #/
      parse_hand(hand_data)
      hand_data = []
    end

    hand_data << line
  end
end

def parse_files
  Dir.glob('data/*').each do |filename|
    parse_file(filename)
  end
end

parse_files
require 'pry'; binding.pry
