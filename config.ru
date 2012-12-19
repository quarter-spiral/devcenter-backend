require 'rubygems'
require 'bundler/setup'

require 'devcenter-backend'

if !ENV['RACK_ENV'] || ENV['RACK_ENV'] == 'development'
  ENV['QS_OAUTH_CLIENT_ID'] ||= 'l738roicmwq76lm3h42gxnjfye2253h'
  ENV['QS_OAUTH_CLIENT_SECRET'] ||= 'ibeylszv9eicleyhpuwqj819vhkl0l5'
end

require 'newrelic_rpm'
require 'new_relic/agent/instrumentation/rack'
require 'ping-middleware'

class NewRelicMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  end
  include NewRelic::Agent::Instrumentation::Rack
end

use NewRelicMiddleware
use Ping::Middleware

run Devcenter::Backend::API
