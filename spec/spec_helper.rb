$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'hiki2md'

def assert(hiki, md)
  converted = Hiki2md.new.convert(hiki)
  expect(converted).to eq(md)
end
