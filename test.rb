lines = File.readlines(ARGV[0])
p lines
outputs = ""
lines.each{|line|
  p line
      if line =~ /\A<<<ruby\z/
        outputs << '```ruby'
        next
      end
}
p outputs
