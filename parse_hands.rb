require 'ostruct'

@hands = []

def parse_hand(hand_data)
  hand = OpenStruct.new

  hand_data.each do |line|
    if line =~ /\ABovada Hand #/
      hand.id, hand.table_id, hand.time =
        line.match(/#(\d+) TBL#(\d+).*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/).captures
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
