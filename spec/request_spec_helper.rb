require 'rack/client'
require 'auth-backend/test_helpers'

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

module Auth
  class Client
    alias raw_initialize initialize
    def initialize(url, options = {})
      raw_initialize(url, options.merge(adapter: [:rack, AUTH_APP]))
    end
  end
end

def client
  return @client if @client

  @client =  Rack::Client.new {
    use AuthenticationInjector
    run API_APP
  }

  def @client.get(url, headers = {}, body = '', &block)
    request('GET', url, headers, body, {}, &block)
  end
  def @client.delete(url, headers = {}, body = '', &block)
    request('DELETE', url, headers, body, {}, &block)
  end

  @client
end

AUTH_HELPERS = Auth::Backend::TestHelpers.new(AUTH_APP)

QS_SPEC_TOKEN ||= AUTH_HELPERS.get_token
def token
  QS_SPEC_TOKEN
end

oauth_app = AUTH_HELPERS.create_app!
ENV['QS_OAUTH_CLIENT_ID'] = oauth_app[:id]
ENV['QS_OAUTH_CLIENT_SECRET'] = oauth_app[:secret]

APP_TOKEN = Devcenter::Backend::Connection.create.auth.create_app_token(oauth_app[:id], oauth_app[:secret])
