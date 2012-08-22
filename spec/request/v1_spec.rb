require_relative '../spec_helper.rb'

require 'json'
require 'uuid'
require 'rack/client'

include Devcenter::Backend

def client
  return @client if @client

  @client = Rack::Client.new {run API}
  def @client.get(url, headers = {}, body = '', &block)
    request('GET', url, headers, body, {}, &block)
  end
  def @client.delete(url, headers = {}, body = '', &block)
    request('DELETE', url, headers, body, {}, &block)
  end

  @client
end

describe Devcenter::Backend::API do
  before do
    @entity1 = UUID.new.generate
    @entity2 = UUID.new.generate

    @connection = ::Devcenter::Backend::Connection.create
  end

  it "is not possible to add a game as a non-developer" do
    old_games = @connection.graph.uuids_by_role('game')

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1])
    response.status.wont_equal 201

    @connection.graph.uuids_by_role('game').size.must_equal old_games.size

    client.post "/v1/developers/#{@entity1}"

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1])
    response.status.must_equal 201

    uuid = JSON.parse(response.body)['uuid']
    uuid.empty?.must_equal false

    new_games = @connection.graph.uuids_by_role('game')
    new_games.size.must_equal old_games.size + 1
    new_games.must_include uuid
  end

  it "can demote developers" do
    old_games = @connection.graph.uuids_by_role('game')

    client.post   "/v1/developers/#{@entity1}"
    client.delete "/v1/developers/#{@entity1}"

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1])
    response.status.wont_equal 201

    @connection.graph.uuids_by_role('game').size.must_equal old_games.size
  end

  it "ensures that games can only be created with a name, a description and at least one developer" do
    client.post "/v1/developers/#{@entity1}"

    response = client.post "/v1/games", {}, JSON.dump(description: "A good game", developers: [@entity1])
    response.status.wont_equal 201

    response = client.post "/v1/games", {}, JSON.dump(name: "    \t",description: "A good game", developers: [@entity1])
    response.status.wont_equal 201

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", developers: [@entity1])
    response.status.wont_equal 201

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "  \t  ", developers: [@entity1])
    response.status.wont_equal 201

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game")
    response.status.wont_equal 201

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [])
    response.status.wont_equal 201

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1])
    response.status.must_equal 201
  end

  it "can list games of a developer" do
    client.post "/v1/developers/#{@entity1}"
    client.post "/v1/developers/#{@entity2}"

    response = client.get "/v1/developers/#{@entity1}/games"
    JSON.parse(response.body).must_equal []
    response = client.get "/v1/developers/#{@entity2}/games"
    JSON.parse(response.body).must_equal []

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1])
    uuid1 = JSON.parse(response.body)['uuid']

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game2", description: "A good game", developers: [@entity2])
    uuid2 = JSON.parse(response.body)['uuid']

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game3", description: "A good game", developers: [@entity1])
    uuid3 = JSON.parse(response.body)['uuid']

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game4", description: "A good game", developers: [@entity2, @entity1])
    uuid4 = JSON.parse(response.body)['uuid']

    response = client.get "/v1/developers/#{@entity1}/games"
    games_of_entity1 =JSON.parse(response.body)
    games_of_entity1.must_include uuid1
    games_of_entity1.wont_include uuid2
    games_of_entity1.must_include uuid3
    games_of_entity1.must_include uuid4

    response = client.get "/v1/developers/#{@entity2}/games"
    games_of_entity2 =JSON.parse(response.body)
    games_of_entity2.wont_include uuid1
    games_of_entity2.must_include uuid2
    games_of_entity2.wont_include uuid3
    games_of_entity2.must_include uuid4
  end

  it "can delete games" do
    client.post "/v1/developers/#{@entity1}"
    client.post "/v1/developers/#{@entity2}"


    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1, @entity2])
    uuid1 = JSON.parse(response.body)['uuid']

    response = client.get "/v1/developers/#{@entity1}/games"
    games_of_entity1 = JSON.parse(response.body)
    games_of_entity1.must_include uuid1

    response = client.get "/v1/developers/#{@entity2}/games"
    games_of_entity1 = JSON.parse(response.body)
    games_of_entity1.must_include uuid1


    games = @connection.graph.uuids_by_role('game')
    games.must_include(uuid1)

    client.delete "/v1/games/#{uuid1}"

    response = client.get "/v1/developers/#{@entity1}/games"
    games_of_entity1 = JSON.parse(response.body)
    games_of_entity1.wont_include uuid1

    response = client.get "/v1/developers/#{@entity2}/games"
    games_of_entity1 =JSON.parse(response.body)
    games_of_entity1.wont_include uuid1

    games = @connection.graph.uuids_by_role('game')
    games.wont_include(uuid1)
  end

  it "can change the configuration of a game" do
    @entity3 = UUID.new.generate
    client.post "/v1/developers/#{@entity1}"
    client.post "/v1/developers/#{@entity2}"
    client.post "/v1/developers/#{@entity3}"


    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1, @entity2])
    game = JSON.parse(response.body)['uuid']

    response = client.get "/v1/games/#{game}"
    config = JSON.parse(response.body)
    config['name'].must_equal "Test Game"
    config['description'].must_equal "A good game"

    developers = config['developers']
    developers.size.must_equal 2
    developers.must_include @entity1
    developers.must_include @entity2

    config['configuration'].must_equal({})
    config['screenshots'].must_equal []

    response = client.put "/v1/games/#{game}", {}, JSON.dump(description: "A bad game")
    config = JSON.parse(response.body)
    config['name'].must_equal "Test Game"
    config['description'].must_equal "A bad game"

    response = client.get "/v1/games/#{game}"
    JSON.parse(response.body).must_equal config

    client.put "/v1/games/#{game}", {}, JSON.dump(screenshots: ['some_url', 'other_url'])
    response = client.get "/v1/games/#{game}"
    config = JSON.parse(response.body)
    config['screenshots'].must_equal ['some_url', 'other_url']

    client.put "/v1/games/#{game}", {}, JSON.dump(screenshots: ['some_url'], configuration: {some: 'cool', shit: ['yeah', true]})
    response = client.get "/v1/games/#{game}"
    config = JSON.parse(response.body)
    config['screenshots'].must_equal ['some_url']
    config['configuration'].must_equal({'some' => 'cool', 'shit' => ['yeah', true]})

    client.put "/v1/games/#{game}", {}, JSON.dump(developers: [@entity1, @entity3])
    response = client.get "/v1/games/#{game}"
    config = JSON.parse(response.body)
    developers = config['developers']
    developers.size.must_equal 2
    developers.must_include @entity1
    developers.wont_include @entity2
    developers.must_include @entity3

    response = client.get "/v1/developers/#{@entity1}/games"
    JSON.parse(response.body).must_include game
    response = client.get "/v1/developers/#{@entity2}/games"
    JSON.parse(response.body).must_equal []
    response = client.get "/v1/developers/#{@entity3}/games"
    JSON.parse(response.body).must_include game
  end
end
