source 'https://rubygems.org'

# Specify your gem's dependencies in devcenter-backend.gemspec
gemspec

#gem 'service-client', path: '../service-client'
gem 'service-client', git: 'git@github.com:quarter-spiral/service-client.git', :tag => 'release-0.0.4'

#gem 'datastore-client', path: '../datastore-client'
gem 'datastore-client', git: 'git@github.com:quarter-spiral/datastore-client.git', :tag => 'release-0.0.3'

#gem 'graph-client', path: '../graph-client'
gem 'graph-client', git: 'git@github.com:quarter-spiral/graph-client.git', :tag => 'release-0.0.2'


group :development, :test do
  #gem 'graph-backend', path: '../graph-backend'
  gem 'graph-backend', git: 'git@github.com:quarter-spiral/graph-backend.git', tag: 'release-0.0.3'

  #gem 'datastore-backend', path: '../datastore-backend'
  gem 'datastore-backend', git: 'git@github.com:quarter-spiral/datastore-backend.git', tag: 'release-0.0.5'

  gem 'rack-client'
  gem 'rack-test'
  gem 'rake'
  gem 'uuid'

  platforms :rbx do
    gem 'bson_ext'
  end
end
