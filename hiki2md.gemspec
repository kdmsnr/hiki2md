# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hiki2md/version'

Gem::Specification.new do |spec|
  spec.name          = "hiki2md"
  spec.version       = Hiki2md::VERSION
  spec.authors       = ["Masanori Kado"]
  spec.email         = ["kdmsnr@gmail.com"]

  spec.summary       = %q{Converter of Hiki to Markdown}
  spec.homepage      = "http://github.com/kdmsnr/hiki2md"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
end
