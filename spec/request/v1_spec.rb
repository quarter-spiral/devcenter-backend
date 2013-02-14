require_relative '../spec_helper.rb'
require_relative '../request_spec_helper.rb'

require 'json'
require 'uuid'
require 'uri'

describe Devcenter::Backend::API do
  before do
    @entity1 = UUID.new.generate
    @entity2 = UUID.new.generate

    @connection = ::Devcenter::Backend::Connection.create
  end

  it "does not work unauthenticated" do
    client.post("/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1])).status.must_equal(403)
    client.post("/v1/developers/#{@entity1}").status.must_equal 403
    client.delete("/v1/developers/#{@entity1}").status.must_equal 403
    client.get("/v1/developers/#{@entity1}/games").status.must_equal 403
  end

  describe "authenticated" do
    before do
      AuthenticationInjector.token = token
    end

    after do
      AuthenticationInjector.reset!
    end

    it "is not possible to add a game as a non-developer" do
      old_games = @connection.graph.uuids_by_role(token, 'game')

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1])
      response.status.wont_equal 201

      @connection.graph.uuids_by_role(token, 'game').size.must_equal old_games.size

      client.post "/v1/developers/#{@entity1}"

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game"}, category: 'Jump n Run')
      response.status.must_equal 201

      uuid = JSON.parse(response.body)['uuid']
      uuid.empty?.must_equal false

      new_games = @connection.graph.uuids_by_role(token, 'game')
      new_games.size.must_equal old_games.size + 1
      new_games.must_include uuid
    end

    it "can demote developers" do
      old_games = @connection.graph.uuids_by_role(token, 'game')

      client.post   "/v1/developers/#{@entity1}"
      client.delete "/v1/developers/#{@entity1}"

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1], category: 'Jump n Run')
      response.status.wont_equal 201

      @connection.graph.uuids_by_role(token, 'game').size.must_equal old_games.size
    end

    it "ensures that games can only be created with a name, a description, at least one developer, a configuration with a type and a category" do
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

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game"}, category: "")
      response.status.wont_equal 201

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game"}, category: "Jump n Run")
      response.status.must_equal 201
    end

    describe "secret" do
      before do
        client.post "/v1/developers/#{@entity1}"
        response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game"}, category: 'Jump n Run')
        @game = JSON.parse(response.body)
      end

      it "enures that each game has it" do
        secret = @game['secret']
        secret.wont_be_nil

        game = JSON.parse(client.get("/v1/games/#{@game['uuid']}").body)
        game['secret'].must_equal secret

        response = client.post "/v1/games", {}, JSON.dump(name: "Test Game 2", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game"}, category: 'Jump n Run')
        game2 = JSON.parse(response.body)
        game2['secret'].wont_be_nil
        game2['secret'].wont_equal secret
      end

      it "can't be changed" do
        response = client.put "/v1/games/#{@game['uuid']}", {}, JSON.dump(name: 'Updated Game', secret: 'bla')
        updated_game = JSON.parse(response.body)
        updated_game['name'].must_equal 'Updated Game'
        updated_game['secret'].wont_equal 'bla'
        updated_game['secret'].must_equal @game['secret']

        updated_game = JSON.parse(client.get("/v1/games/#{@game['uuid']}").body)
        updated_game['name'].must_equal 'Updated Game'
        updated_game['secret'].wont_equal 'bla'
        updated_game['secret'].must_equal @game['secret']
      end

      it "can be chosen on creation" do
        chosen_secret = @game['secret'].reverse
        response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", secret: chosen_secret, developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game"}, category: 'Jump n Run')
        game2 = JSON.parse(response.body)
        game2['secret'].wont_be_nil
        game2['secret'].wont_equal chosen_secret

        got_game = JSON.parse(client.get("/v1/games/#{game2['uuid']}").body)
        got_game['secret'].wont_equal chosen_secret
        got_game['secret'].must_equal game2['secret']
      end

      it "is not included in the public data" do
        secret = JSON.parse(client.get("/v1/games/#{@game['uuid']}").body)['secret']
        secret.wont_be_nil

        response = client.get "/v1/public/games?games=#{URI.escape(JSON.dump([@game['uuid']]))}"
        public_data = JSON.parse(response.body)
        public_data['games'].size.must_equal 1
        game = public_data['games'].first
        game['uuid'].must_equal @game['uuid']
        game.values.include?(secret).must_equal false
      end
    end

    describe "game types" do
      before do
        @game = {name: "Test Game", description: "A good game", developers: [@entity1], category: 'Jump n Run'}
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

    it "can set a game's credits line" do
      client.post "/v1/developers/#{@entity1}"
      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1], configuration:       {type: "html5", url: "http://example.com/game1"}, category: 'Jump n Run')
      game = JSON.parse(response.body)['uuid']
      config = JSON.parse(client.get("/v1/games/#{game}").body)
      config['credits'].must_be_nil

      client.put "/v1/games/#{game}", {}, JSON.dump(credits: "Quarter Spiral Inc.")
      config = JSON.parse(client.get("/v1/games/#{game}").body)
      config['credits'].must_equal "Quarter Spiral Inc."

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game 2", description: "A good game", developers: [@entity1], configuration:       {type: "html5", url: "http://example.com/game1"}, category: 'Jump n Run', credits: "Quarter Spiral Co.")
      game = JSON.parse(response.body)['uuid']
      config = JSON.parse(client.get("/v1/games/#{game}").body)
      config['credits'].must_equal "Quarter Spiral Co."
    end

    it "can set a game's credits URL" do
      client.post "/v1/developers/#{@entity1}"
      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1], configuration:       {type: "html5", url: "http://example.com/game1"}, category: 'Jump n Run')
      game = JSON.parse(response.body)['uuid']
      config = JSON.parse(client.get("/v1/games/#{game}").body)
      config['credits_url'].must_be_nil

      client.put "/v1/games/#{game}", {}, JSON.dump(credits_url: "http://quarterspiral.com")
      config = JSON.parse(client.get("/v1/games/#{game}").body)
      config['credits_url'].must_equal "http://quarterspiral.com"

      client.put "/v1/games/#{game}", {}, JSON.dump(credits_url: "")
      config = JSON.parse(client.get("/v1/games/#{game}").body)
      config['credits_url'].must_be_nil

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game 2", description: "A good game", developers: [@entity1], configuration:       {type: "html5", url: "http://example.com/game1"}, category: 'Jump n Run', credits_url: "http://quarterspiral.com/2")
      game = JSON.parse(response.body)['uuid']
      config = JSON.parse(client.get("/v1/games/#{game}").body)
      config['credits_url'].must_equal "http://quarterspiral.com/2"
    end

    it "can only save http and https credit urls" do
      client.post "/v1/developers/#{@entity1}"
      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game 2", description: "A good game", developers: [@entity1], configuration:       {type: "html5", url: "http://example.com/game1"}, category: 'Jump n Run', credits_url: "http://quarterspiral.com/2")
      game = JSON.parse(response.body)['uuid']

      config = JSON.parse(client.get("/v1/games/#{game}").body)
      config['credits_url'].must_equal "http://quarterspiral.com/2"

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game 2", description: "A good game", developers: [@entity1], configuration:       {type: "html5", url: "http://example.com/game1"}, category: 'Jump n Run', credits_url: "https://quarterspiral.com/2")
      game = JSON.parse(response.body)['uuid']
      config = JSON.parse(client.get("/v1/games/#{game}").body)
      config['credits_url'].must_equal "https://quarterspiral.com/2"

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game 2", description: "A good game", developers: [@entity1], configuration:       {type: "html5", url: "http://example.com/game1"}, category: 'Jump n Run', credits_url: "ftp://quarterspiral.com")
      response.wont_equal 201

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game 2", description: "A good game", developers: [@entity1], configuration:       {type: "html5", url: "http://example.com/game1"}, category: 'Jump n Run', credits_url: "javascript:alert(1)")
      response.wont_equal 201

      response = client.put "/v1/games/#{game}", {}, JSON.dump(credits_url: "ftp://quarterspiral.com/2")
      config = JSON.parse(client.get("/v1/games/#{game}").body)
      config['credits_url'].must_equal "https://quarterspiral.com/2"
    end

    it "can list games of a developer" do
      client.post "/v1/developers/#{@entity1}"
      client.post "/v1/developers/#{@entity2}"

      response = client.get "/v1/developers/#{@entity1}/games"
      JSON.parse(response.body).must_equal({})
      response = client.get "/v1/developers/#{@entity2}/games"
      JSON.parse(response.body).must_equal({})

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game1"}, category: 'Jump n Run')
      uuid1 = JSON.parse(response.body)['uuid']

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game2", description: "A good game", developers: [@entity2], configuration: {type: "html5", url: "http://example.com/game2"}, category: 'Jump n Run')
      uuid2 = JSON.parse(response.body)['uuid']

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game3", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game3"}, category: 'Jump n Run')
      uuid3 = JSON.parse(response.body)['uuid']

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game4", description: "A good game", developers: [@entity2, @entity1], configuration: {type: "html5", url: "http://example.com/game4"}, category: 'Jump n Run')
      uuid4 = JSON.parse(response.body)['uuid']

      response = client.get "/v1/developers/#{@entity1}/games"
      games_of_entity1 =JSON.parse(response.body)

      games_of_entity1.keys.must_include uuid1
      games_of_entity1.keys.wont_include uuid2
      games_of_entity1.keys.must_include uuid3
      games_of_entity1.keys.must_include uuid4

      response = client.get "/v1/developers/#{@entity2}/games"
      games_of_entity2 =JSON.parse(response.body)
      games_of_entity2.keys.wont_include uuid1
      games_of_entity2.keys.must_include uuid2
      games_of_entity2.keys.wont_include uuid3
      games_of_entity2.keys.must_include uuid4

      games_of_entity2[uuid2]['uuid'].must_equal uuid2
      games_of_entity2[uuid2]['name'].must_equal 'Test Game2'
      games_of_entity2[uuid2]['configuration']['type'].must_equal 'html5'
      games_of_entity2[uuid2]['configuration']['url'].must_equal 'http://example.com/game2'
      games_of_entity2[uuid2]['secret'].wont_be_nil

      games_of_entity2[uuid4]['uuid'].must_equal uuid4
      games_of_entity2[uuid4]['name'].must_equal 'Test Game4'
      games_of_entity2[uuid4]['configuration']['type'].must_equal 'html5'
      games_of_entity2[uuid4]['configuration']['url'].must_equal 'http://example.com/game4'
      games_of_entity2[uuid4]['secret'].wont_be_nil
    end

    it "can delete games" do
      client.post "/v1/developers/#{@entity1}"
      client.post "/v1/developers/#{@entity2}"


      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1, @entity2], configuration: {type: "html5", url: "http://example.com/game"}, category: 'Jump n Run')
      uuid1 = JSON.parse(response.body)['uuid']

      response = client.get "/v1/developers/#{@entity1}/games"
      games_of_entity1 = JSON.parse(response.body)
      games_of_entity1.must_include uuid1

      response = client.get "/v1/developers/#{@entity2}/games"
      games_of_entity1 = JSON.parse(response.body)
      games_of_entity1.must_include uuid1


      games = @connection.graph.uuids_by_role(token, 'game')
      games.must_include(uuid1)

      client.delete "/v1/games/#{uuid1}"

      response = client.get "/v1/developers/#{@entity1}/games"
      games_of_entity1 = JSON.parse(response.body)
      games_of_entity1.wont_include uuid1

      response = client.get "/v1/developers/#{@entity2}/games"
      games_of_entity1 =JSON.parse(response.body)
      games_of_entity1.wont_include uuid1

      games = @connection.graph.uuids_by_role(token, 'game')
      games.wont_include(uuid1)
    end

    it "can change the configuration of a game" do
      @entity3 = UUID.new.generate
      client.post "/v1/developers/#{@entity1}"
      client.post "/v1/developers/#{@entity2}"
      client.post "/v1/developers/#{@entity3}"

      response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1, @entity2], configuration: {type: "html5", url: "http://example.com/game"}, category: 'Jump n Run')
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
      JSON.parse(response.body).must_equal({})
      response = client.get "/v1/developers/#{@entity3}/games"
      JSON.parse(response.body).must_include game
    end

    it "can remove developers using the generic update method" do
      client.post "/v1/developers/#{@entity1}"
      client.post "/v1/developers/#{@entity2}"

      game_data = {name: "Test Game", description: "A good game", developers: [@entity1, @entity2], configuration: {type: "html5", url: "http://example.com/game"}, category: 'Jump n Run'}
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

      game_data = {name: "Test Game", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game"}, category: 'Jump n Run'}
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

      game_data = {name: "Test Game", description: "A good game", developers: [@entity1, @entity2], configuration: {type: "html5", url: "http://example.com/game"}, category: 'Jump n Run'}
      response = client.post "/v1/games", {}, JSON.dump(game_data)
      game = JSON.parse(response.body)['uuid']

      response = client.delete "/v1/games/#{game}/developers/#{@entity2}"
      config = JSON.parse(response.body)
      config['developers'].must_equal [@entity1]

      response = client.get "/v1/games/#{game}"
      config = JSON.parse(response.body)
      config['developers'].must_equal [@entity1]
    end

    it "does not try to modify non-game resources" do
      @connection.datastore.set(@entity2, token, name: 'Not a game')
      response = client.put "/v1/games/#{@entity2}", {}, JSON.dump(name: 'Update')
      data = JSON.parse(response.body)
      data['error'].must_equal "Entity not a game (#{@entity2})"
    end
  end
end
