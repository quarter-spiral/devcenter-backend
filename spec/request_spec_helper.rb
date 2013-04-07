require 'rack/client'
require 'auth-backend/test_helpers'
require 'faraday'

include Devcenter::Backend

class AuthenticationInjector
  def self.token=(token)
    @token = token
  end

  def self.token
    @token
  end

  def self.reset!
    @token = nil
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    if token = self.class.token
      env['HTTP_AUTHORIZATION'] = "Bearer #{token}"
    end

    @app.call(env)
  end
end

ENV['QS_AUTH_BACKEND_URL'] = 'http://auth-backend.dev'

API_APP  = API.new
AUTH_APP = Auth::Backend::App.new(test: true)

module Playercenter::Backend
  class Connection
    alias raw_initialize initialize
    def initialize(*args)
      result = raw_initialize(*args)

      graph_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, GRAPH_BACKEND])
      @graph.client.raw.adapter = graph_adapter

      devcenter_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, API_APP])
      @devcenter.client.raw.adapter = devcenter_adapter

      result
    end
  end
end


module Auth
  class Client
    alias raw_initialize initialize
    def initialize(url, options = {})
      raw_initialize(url, options.merge(adapter: [:rack, AUTH_APP]))
    end
  end
end

class ContentTypeInjector
  def initialize(app)
    @app = app
  end

  def call(env)
    env['CONTENT_TYPE'] = 'application/json'
    env['CONTENT_LENGTH'] = env['rack.input'].length
    @app.call(env)
  end
end

def client
  return @client if @client

  @client =  Rack::Client.new {
    use AuthenticationInjector
    use ContentTypeInjector
    run API_APP
  }

  def @client.get(url, headers = {}, body = '', &block)
    params = body && !body.empty? ? JSON.parse(body) : {}
    uri = URI.parse(url)
    uri.query ||= ''
    uri.query += "&" + Faraday::Utils.build_nested_query(params)
    request('GET', uri.to_s, headers, nil, {}, &block)
  end

  def @client.delete(url, headers = {}, body = '', &block)
    params = body && !body.empty? ? JSON.parse(body) : {}
    uri = URI.parse(url)
    uri.query ||= ''
    uri.query += "&" + Faraday::Utils.build_nested_query(params)
    request('DELETE', uri.to_s, headers, nil, {}, &block)
  end

  @client
end

AUTH_HELPERS = Auth::Backend::TestHelpers.new(AUTH_APP)

QS_SPEC_TOKEN ||= AUTH_HELPERS.get_token
def token
  @token ||= AUTH_HELPERS.get_token
end

def user
  @user ||= AUTH_HELPERS.user_data
end

oauth_app = AUTH_HELPERS.create_app!
ENV['QS_OAUTH_CLIENT_ID'] = oauth_app[:id]
ENV['QS_OAUTH_CLIENT_SECRET'] = oauth_app[:secret]

APP_TOKEN = Devcenter::Backend::Connection.create.auth.create_app_token(oauth_app[:id], oauth_app[:secret])

QS_CANVAS_APP_URL = 'http://example.com/canvas'

require_relative './utility_methods'
include UtilityMethods
