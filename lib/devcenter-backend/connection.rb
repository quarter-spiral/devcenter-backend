module Devcenter::Backend
  class Connection
    attr_reader :datastore, :graph

    def self.create
      self.new(
        ENV['QS_DATASTORE_BACKEND_URL'] || 'http://datastore-backend.dev',
        ENV['QS_GRAPH_BACKEND_URL'] || 'http://graph-backend.dev'
      )
    end

    def initialize(datastore_backend_url, graph_backend_url)
      @datastore = ::Datastore::Client.new(datastore_backend_url)
      @graph = ::Graph::Client.new(graph_backend_url)
    end
  end
end
