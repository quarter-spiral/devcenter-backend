require_relative '../spec_helper.rb'

require 'json'
require 'uuid'
require 'rack/client'

include Devcenter::Backend

def client
  @client ||= Rack::Client.new {run API}
end

describe Devcenter::Backend::API do
  before do
    @entity1 = UUID.new.generate
    @connection = ::Devcenter::Backend::Connection.create
  end

  it "is not possible to add a game as a non-developer" do
    old_games = @connection.graph.uuids_by_role('game')

    response = client.post "/v1/games", {}, name: "Test Game", description: "A good game", developers: [@entity1]
    response.status.wont_equal 201

    @connection.graph.uuids_by_role('game').size.must_equal old_games.size

    client.post "/v1/developers/#{@entity1}"

    response = client.post "/v1/games", {}, name: "Test Game", description: "A good game", developers: [@entity1]
    response.status.must_equal 201

    uuid = JSON.parse(response.body)['uuid']
    uuid.empty?.must_equal false

    new_games = @connection.graph.uuids_by_role('game')
    new_games.size.must_equal old_games.size + 1
    new_games.must_include uuid
  end
end
