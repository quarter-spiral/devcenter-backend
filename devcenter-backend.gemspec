# -*- encoding: utf-8 -*-
require File.expand_path('../lib/devcenter-backend/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Thorben Schröder"]
  gem.email         = ["info@thorbenschroeder.de"]
  gem.description   = %q{A backend to handle everything game/developer related.}
  gem.summary       = %q{A backend to handle everything game/developer related.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "devcenter-backend"
  gem.require_paths = ["lib"]
  gem.version       = Devcenter::Backend::VERSION
end
