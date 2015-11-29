require 'ostruct'

@hands = []

def parse_file(filename)
  File.read(filename).split("\r\n").each do |line|
    if line =~ /\ABovada Hand #/
      hand = OpenStruct.new
      hand.id, hand.table_id, hand.time =
        line.match(/#(\d+) TBL#(\d+).*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/).captures

      @hands << hand
    end
  end
end

def parse_files
  Dir.glob('data/*').each do |filename|
    parse_file(filename)
  end
end

parse_files
require 'pry'; binding.pry
