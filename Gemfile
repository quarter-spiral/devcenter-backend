source 'https://rubygems.org'
source "https://user:We267RFF7BfwVt4LdqFA@privategems.herokuapp.com/"

# Specify your gem's dependencies in devcenter-backend.gemspec
gemspec

#gem 'service-client', path: '../service-client'
#gem 'datastore-client', path: '../datastore-client'
#gem 'graph-client', path: '../graph-client'
#
platforms :ruby do
  gem 'thin'
end

group :development, :test do
  #gem 'graph-backend', path: '../graph-backend'
  gem 'graph-backend', '0.0.6'

  #gem 'datastore-backend', path: '../datastore-backend'
  gem 'datastore-backend', '0.0.7'

  gem 'rack-client'
  gem 'rack-test'
  gem 'rake'
  gem 'uuid'

  gem 'auth-backend', "~> 0.0.3"
  gem 'sqlite3'
  gem 'sinatra_warden', git: 'https://github.com/quarter-spiral/sinatra_warden.git'
  gem 'songkick-oauth2-provider', git: 'https://github.com/quarter-spiral/oauth2-provider.git'

  platforms :rbx do
    gem 'bson_ext'
  end
end
