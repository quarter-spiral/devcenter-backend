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

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game"})
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

  it "ensures that games can only be created with a name, a description, at least one developer and a configuration with a type" do
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
    response.status.wont_equal 201

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1], configuration: {})
    response.status.wont_equal 201

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game"})
    response.status.must_equal 201
  end

  describe "game types" do
    before do
      @game = {name: "Test Game", description: "A good game", developers: [@entity1]}
      client.post "/v1/developers/#{@entity1}"
    end
    it "does not allow bullshit" do
      response = client.post "/v1/games", {}, JSON.dump(@game.merge(configuration: {type: "bullshit"}))
      response.status.wont_equal 201
    end

    it "allows html5 with a url" do
      response = client.post "/v1/games", {}, JSON.dump(@game.merge(configuration: {type: "html5"}))
      response.status.wont_equal 201

      response = client.post "/v1/games", {}, JSON.dump(@game.merge(configuration: {url: "http://example.com/game"}))
      response.status.wont_equal 201

      response = client.post "/v1/games", {}, JSON.dump(@game.merge(configuration: {type: 'html5', url: ""}))
      response.status.wont_equal 201

      response = client.post "/v1/games", {}, JSON.dump(@game.merge(configuration: {type: 'html5', url: "http://example.com/game"}))
      response.status.must_equal 201
    end

    it "allows flash games with a url" do
      response = client.post "/v1/games", {}, JSON.dump(@game.merge(configuration: {type: "flash"}))
      response.status.wont_equal 201

      response = client.post "/v1/games", {}, JSON.dump(@game.merge(configuration: {url: "http://example.com/game.swf"}))
      response.status.wont_equal 201

      response = client.post "/v1/games", {}, JSON.dump(@game.merge(configuration: {type: 'flash', url: ""}))
      response.status.wont_equal 201

      response = client.post "/v1/games", {}, JSON.dump(@game.merge(configuration: {type: 'flash', url: "http://example.com/game.swf"}))
      response.status.must_equal 201
    end

    describe "initial games" do
      it "creation" do
        response = client.post "/v1/games", {}, JSON.dump(@game.merge(configuration: {type: "initial"}))
        response.status.must_equal 201
      end

      it "does not allow to change a game type back to initial" do
        response = client.post "/v1/games", {}, JSON.dump(@game.merge(configuration: {type: 'flash', url: "http://example.com/game.swf"}))
        game = JSON.parse(response.body)['uuid']

        response = client.put "/v1/games/#{game}", {}, JSON.dump(configuration: {type: 'initial'})
        response.status.wont_equal 200

        config = JSON.parse(client.get("/v1/games/#{game}").body)
        config['configuration']['type'].must_equal 'flash'
        config['configuration']['url'].must_equal 'http://example.com/game.swf'
      end

      it "can stay with the initial game type" do
        response = client.post "/v1/games", {}, JSON.dump(@game.merge(configuration: {type: 'initial'}))
        game = JSON.parse(response.body)['uuid']

        response = client.put "/v1/games/#{game}", {}, JSON.dump(name: 'updated', configuration: {type: 'initial'})
        response.status.must_equal 200

        config = JSON.parse(client.get("/v1/games/#{game}").body)
        config['name'].must_equal 'updated'
        config['configuration']['type'].must_equal 'initial'
      end
    end
  end

  it "can list games of a developer" do
    client.post "/v1/developers/#{@entity1}"
    client.post "/v1/developers/#{@entity2}"

    response = client.get "/v1/developers/#{@entity1}/games"
    JSON.parse(response.body).must_equal []
    response = client.get "/v1/developers/#{@entity2}/games"
    JSON.parse(response.body).must_equal []

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game1"})
    uuid1 = JSON.parse(response.body)['uuid']

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game2", description: "A good game", developers: [@entity2], configuration: {type: "html5", url: "http://example.com/game2"})
    uuid2 = JSON.parse(response.body)['uuid']

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game3", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game3"})
    uuid3 = JSON.parse(response.body)['uuid']

    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game4", description: "A good game", developers: [@entity2, @entity1], configuration: {type: "html5", url: "http://example.com/game4"})
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


    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1, @entity2], configuration: {type: "html5", url: "http://example.com/game"})
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


    response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1, @entity2], configuration: {type: "html5", url: "http://example.com/game"})
    game = JSON.parse(response.body)['uuid']

    response = client.get "/v1/games/#{game}"
    config = JSON.parse(response.body)
    config['name'].must_equal "Test Game"
    config['description'].must_equal "A good game"

    developers = config['developers']
    developers.size.must_equal 2
    developers.must_include @entity1
    developers.must_include @entity2

    config['developer_configuration'].must_equal({})
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

    client.put "/v1/games/#{game}", {}, JSON.dump(screenshots: ['some_url'], developer_configuration: {some: 'cool', shit: ['yeah', true]})
    response = client.get "/v1/games/#{game}"
    config = JSON.parse(response.body)
    config['screenshots'].must_equal ['some_url']
    config['developer_configuration'].must_equal({'some' => 'cool', 'shit' => ['yeah', true]})

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

  it "can remove developers using the generic update method" do
    client.post "/v1/developers/#{@entity1}"
    client.post "/v1/developers/#{@entity2}"

    game_data = {name: "Test Game", description: "A good game", developers: [@entity1, @entity2], configuration: {type: "html5", url: "http://example.com/game"}}
    response = client.post "/v1/games", {}, JSON.dump(game_data)
    game = JSON.parse(response.body)['uuid']

    dev_data = game_data.clone
    dev_data[:developers] = [@entity1]
    client.put "/v1/games/#{game}", {}, JSON.dump(dev_data)

    response = client.get "/v1/games/#{game}"
    config = JSON.parse(response.body)
    config['developers'].must_equal [@entity1]
  end

  it "can add developers using the special endpoint" do
    client.post "/v1/developers/#{@entity1}"
    client.post "/v1/developers/#{@entity2}"

    game_data = {name: "Test Game", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game"}}
    response = client.post "/v1/games", {}, JSON.dump(game_data)
    game = JSON.parse(response.body)['uuid']

    response = client.post "/v1/games/#{game}/developers/#{@entity2}"
    config = JSON.parse(response.body)
    config['developers'].must_equal [@entity1, @entity2]

    response = client.get "/v1/games/#{game}"
    config = JSON.parse(response.body)
    config['developers'].must_equal [@entity1, @entity2]
  end

  it "can add developers using the special endpoint" do
    client.post "/v1/developers/#{@entity1}"
    client.post "/v1/developers/#{@entity2}"

    game_data = {name: "Test Game", description: "A good game", developers: [@entity1, @entity2], configuration: {type: "html5", url: "http://example.com/game"}}
    response = client.post "/v1/games", {}, JSON.dump(game_data)
    game = JSON.parse(response.body)['uuid']

    response = client.delete "/v1/games/#{game}/developers/#{@entity2}"
    config = JSON.parse(response.body)
    config['developers'].must_equal [@entity1]

    response = client.get "/v1/games/#{game}"
    config = JSON.parse(response.body)
    config['developers'].must_equal [@entity1]
  end

  describe "game types" do
    before do
      @game_data = {name: "Test Game", description: "A good game", developers: [@entity1], configuration: {type: 'initial'}}
      client.post "/v1/developers/#{@entity1}"
      response = client.post "/v1/games", {}, JSON.dump(@game_data)
      @game = JSON.parse(response.body)['uuid']
    end

    it "doesn't allow bullshit venues" do
      response = client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'facebook' => true, 'bullshit' => true})
      response.status.wont_equal 200
      JSON.parse(response.body)['error'].wont_be_empty
    end

    it "can have multiple venues" do
      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'facebook' => true, 'galaxy-spiral' => true})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      (!!config['venues']['facebook']).must_equal true
      (!!config['venues']['galaxy-spiral']).must_equal true
    end

    it "can add and remove facebook venue" do
      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {facebook: true})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      (!!config['venues']['facebook']).must_equal true

      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {facebook: false})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      (!!config['venues']['facebook']).must_equal false

      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'galaxy-spiral' => true})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      (!!config['venues']['facebook']).must_equal false
    end

    it "can add and remove galaxy-spiral venue" do
      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'galaxy-spiral' => true})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      (!!config['venues']['galaxy-spiral']).must_equal true

      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'galaxy-spiral' => false})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      (!!config['venues']['galaxy-spiral']).must_equal false

      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {facebook: true})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      (!!config['venues']['galaxy-spiral']).must_equal false
    end
  end
end
