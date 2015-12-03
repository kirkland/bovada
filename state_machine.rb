class StateMachine
  def event(line)
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
