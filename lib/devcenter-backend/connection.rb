module Devcenter::Backend
  class Connection
    attr_reader :datastore, :graph, :auth, :cache

    def self.create
      self.new(
        ENV['QS_DATASTORE_BACKEND_URL'] || 'http://datastore-backend.dev',
        ENV['QS_GRAPH_BACKEND_URL'] || 'http://graph-backend.dev',
        ENV['QS_AUTH_BACKEND_URL'] || 'http://auth-backend.dev'
      )
    end

    def initialize(datastore_backend_url, graph_backend_url, auth_backend_url)
      @datastore = ::Datastore::Client.new(datastore_backend_url)
      @graph = ::Graph::Client.new(graph_backend_url)
      @auth = ::Auth::Client.new(auth_backend_url)
      @cache = ::Cache::Client.new(::Cache::Backend::IronCache, ENV['IRON_CACHE_PROJECT_ID'], ENV['IRON_CACHE_TOKEN'], ENV['IRON_CACHE_CACHE'])
    end
  end
end