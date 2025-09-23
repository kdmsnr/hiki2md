$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'hiki2md'

def assert(hiki, md)
  interwiki_map = {
    'Google' => 'https://www.google.com/search?q=',
    'ruby-talk' => 'http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/'
  }
  converted = Hiki2md.new(interwiki_map: interwiki_map).convert(hiki)
  expect(converted).to eq(md)
end
