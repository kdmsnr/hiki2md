lines = File.readlines(ARGV[0])
outputs = []
lines.each{|line|
      if line =~ /\A<<<\s*(.+)/
        form = $1
        outputs << "```#{form}\n"
        next
      end
}
p outputs
