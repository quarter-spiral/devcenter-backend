require 'rubygems'
require 'bundler/setup'

if !ENV['RACK_ENV'] || ENV['RACK_ENV'] == 'development'
  ENV['QS_OAUTH_CLIENT_ID'] ||= 'l738roicmwq76lm3h42gxnjfye2253h'
  ENV['QS_OAUTH_CLIENT_SECRET'] ||= 'ibeylszv9eicleyhpuwqj819vhkl0l5'
  ENV['QS_STRIPE_SECRET_KEY'] ||= 'sk_test_gQ3snq05Bqmj4hFSr3LI74EA'
end

require 'devcenter-backend'

require 'ping-middleware'
use Ping::Middleware

require 'rack/crossdomain/xml'
use Rack::Crossdomain::Xml::Middleware

require 'rack/fake_method'
use Rack::FakeMethod::Middleware

require 'raven'
require 'qs/request/tracker/raven_processor'
Raven.configure do |config|
  config.tags = {'app' => 'devcenter-backend'}
  config.processors = [Raven::Processor::SanitizeData, Qs::Request::Tracker::RavenProcessor]
end
use Raven::Rack
use Qs::Request::Tracker::Middleware
run Devcenter::Backend::API
