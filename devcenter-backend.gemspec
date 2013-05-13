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

  gem.add_dependency 'rack', '~> 1.4.5'
  gem.add_dependency 'grape', '~> 0.4.0'
  gem.add_dependency 'json', '~> 1.7.7'
  gem.add_dependency 'datastore-client', '>=0.0.11'
  gem.add_dependency 'graph-client', '>=0.0.12'
  gem.add_dependency 'auth-client', '>=0.0.15'
  gem.add_dependency 'ping-middleware', '~> 0.0.2'
  gem.add_dependency 'grape_newrelic', '~> 0.0.4'
  gem.add_dependency 'cache-client', '~> 0.0.4'
  gem.add_dependency 'cache-backend-iron-cache', '~> 0.0.4'
  gem.add_dependency 'uuid'
  gem.add_dependency 'stripe', '~> 1.7.11'
  gem.add_dependency 'tracking-client', '>= 0.0.6'
  gem.add_dependency 'rack-crossdomain-xml', '>= 0.0.1'
end
