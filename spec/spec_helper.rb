ENV['RACK_ENV'] ||= 'test'
ENV['QS_STRIPE_SECRET_KEY'] ||= 'sk_test_gQ3snq05Bqmj4hFSr3LI74EA'

Bundler.require

require 'rack/client'

require 'minitest/autorun'

require 'devcenter-backend'

require 'datastore-backend'
require 'auth-backend'
require 'graph-backend'
require 'playercenter-backend'
require 'playercenter-client'

GRAPH_BACKEND = Graph::Backend::API.new
module Auth::Backend
  class Connection
    alias raw_initialize initialize
    def initialize(*args)
      result = raw_initialize(*args)

      graph_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, GRAPH_BACKEND])
      @graph.client.raw.adapter = graph_adapter

      result
    end
  end
end

module Devcenter::Backend
  class Connection
    alias raw_initialize initialize
    def initialize(*args)
      result = raw_initialize(*args)

      datatstore_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, Datastore::Backend::API.new])
      @datastore.client.raw.adapter = datatstore_adapter

      graph_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, GRAPH_BACKEND])
      @graph.client.raw.adapter = graph_adapter

      result
    end
  end
end

def wipe_graph!
  connection = Graph::Backend::Connection.create.neo4j
  (connection.find_node_auto_index('uuid:*') || []).each do |node|
    connection.delete_node!(node)
  end
end
wipe_graph!
