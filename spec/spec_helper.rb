Bundler.setup

require 'minitest/autorun'

require 'devcenter-backend'

require 'datastore-backend'
require 'graph-backend'

module Devcenter::Backend
  class Connection
    alias raw_initialize initialize
    def initialize(*args)
      result = raw_initialize(*args)

      datatstore_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, Datastore::Backend::API.new])
      @datastore.client.raw.adapter = datatstore_adapter

      graph_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, Graph::Backend::API.new])
      @graph.client.raw.adapter = graph_adapter

      result
    end
  end
end
