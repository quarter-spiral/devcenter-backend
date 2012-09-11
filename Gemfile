source 'https://rubygems.org'

private_source = "https://user:#{ENV['QS_GEMS_PASSWORD']}@privategems.herokuapp.com/"
puts "Source: #{private_source}"
source private_source

# Specify your gem's dependencies in devcenter-backend.gemspec
gemspec

#gem 'service-client', path: '../service-client'
#gem 'datastore-client', path: '../datastore-client'
#gem 'graph-client', path: '../graph-client'

group :development, :test do
  #gem 'graph-backend', path: '../graph-backend'
  gem 'graph-backend', '0.0.3'

  #gem 'datastore-backend', path: '../datastore-backend'
  gem 'datastore-backend', '0.0.5'

  gem 'rack-client'
  gem 'rack-test'
  gem 'rake'
  gem 'uuid'

  platforms :rbx do
    gem 'bson_ext'
  end
end
