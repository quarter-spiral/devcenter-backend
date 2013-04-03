require_relative '../spec_helper.rb'
require_relative '../request_spec_helper.rb'

require 'uuid'

def gather_response(method, url, options)
  client.send(method, url, {}, options)
end

def must_be_allowed(method, url, options = {})
  response = gather_response(method, url, options)
  [200, 201].must_include response.status
end

def must_be_forbidden(method, url, options = {})
  response = gather_response(method, url, options)
  response.status.must_equal 403
end

def with_system_level_privileges
  old_token = AuthenticationInjector.token
  AuthenticationInjector.token = APP_TOKEN
  result = yield
  AuthenticationInjector.token = old_token
  result
end

def wont_be_a_developer(uuid)
  @connection.graph.uuids_by_role(APP_TOKEN, 'developer').wont_include(uuid)
end

def must_be_a_developer(uuid)
  @connection.graph.uuids_by_role(APP_TOKEN, 'developer').must_include(uuid)
end

def make_developer!(uuid)
  with_system_level_privileges do
    client.post("/v1/developers/#{uuid}")
  end
  must_be_a_developer(uuid)
end

def delete_all_games!
  @connection.graph.uuids_by_role(APP_TOKEN, 'game').each do |game|
    with_system_level_privileges do
      client.delete "/v1/games/#{game}"
    end
  end
  @connection.graph.uuids_by_role(APP_TOKEN, 'game').must_equal([])
end

def create_game!(options)
  make_developer!(@yourself)
  response = with_system_level_privileges do
    client.post "/v1/games", {}, JSON.dump(options)
  end
  JSON.parse(response.body)['uuid']
end

def games_of_a_developer(uuid)
  with_system_level_privileges do
    JSON.parse(client.get("/v1/developers/#{uuid}/games").body).keys
  end
end

def must_be_developer_of_game(uuid, game)
  games_of_a_developer(uuid).must_include(game)
end

def wont_be_developer_of_game(uuid, game)
  games_of_a_developer(uuid).wont_include(game)
end

def get_game(game)
  response = with_system_level_privileges do
     client.get("/v1/games/#{game}")
  end
  response.status.must_equal 200
  JSON.parse(response.body)
end

def game_must_exist(game)
  get_game(game)['uuid'].must_equal(game)
end

def game_wont_exist(game)
  response = with_system_level_privileges do
     client.get("/v1/games/#{game}")
  end
  response.status.must_equal 404
end

def make_developer_of_game!(uuid, game)
  make_developer!(uuid)
  with_system_level_privileges do
    client.post "/v1/games/#{game}/developers/#{uuid}"
  end
end

describe Devcenter::Backend::API do
  before do
    AUTH_HELPERS.delete_existing_users!
    AUTH_HELPERS.create_user!

    AuthenticationInjector.reset!

    @connection = ::Devcenter::Backend::Connection.create

    delete_all_games!

    @yourself = user['uuid']
    @game_options = {name: "Test Game", description: "A good game", developers: [@yourself], configuration: {type: "html5", url: "http://example.com/game"}, category: 'Jump n Run'}
    @someone_else = UUID.new.generate
  end

  after do
    AuthenticationInjector.reset!
  end

  describe "unauthenticated" do
    #  - You can retrieve all public information without any authentication
    it "can get a list of games" do
      must_be_allowed(:get, "/v1/public/games")
    end

    #  - You cannot access any other information when not authenticated
    it "cannot promote any entity to become a developer" do
      must_be_forbidden(:post, "/v1/developers/#{@yourself}")
      wont_be_a_developer(@yourself)
    end

    it "cannot demote an entity from being a developer" do
      make_developer!(@yourself)

      must_be_forbidden(:delete, "/v1/developers/#{@yourself}")
      must_be_a_developer(@yourself)
    end

    it "cannot list games of a developer" do
      make_developer!(@yourself)
      must_be_forbidden(:get, "/v1/developers/#{@yourself}/games")
    end

    it "cannot add a game" do
      must_be_forbidden(:post, "/v1/games", JSON.dump(@game_options))
      games_of_a_developer(@yourself).must_be_empty
    end

    it "cannot add a developer to a game" do
      game = create_game!(@game_options)
      make_developer!(@someone_else)

      must_be_forbidden(:post, "/v1/games/#{game}/developers/#{@someone_else}")

      must_be_developer_of_game(@yourself, game)
      wont_be_developer_of_game(@someone_else, game)
    end

    it "cannot remove a developer from a game" do
      game = create_game!(@game_options)
      make_developer_of_game!(@someone_else, game)

      must_be_forbidden(:delete, "/v1/games/#{game}/developers/#{@yourself}")
      must_be_developer_of_game(@yourself, game)
      must_be_developer_of_game(@someone_else, game)
    end

    it "cannot delete a game" do
      game = create_game!(@game_options)
      must_be_forbidden(:delete, "/v1/games/#{game}")
      game_must_exist(game)
    end

    it "cannot change a game" do
      game = create_game!(@game_options)
      must_be_forbidden(:put, "/v1/games/#{game}", JSON.dump(name: "Updated game"))
      get_game(game)['name'].wont_equal 'Updated game'
    end

    it "cannot retrieve private game information" do
      game = create_game!(@game_options)
      must_be_forbidden(:get, "/v1/games/#{game}")
    end
  end

  describe "authenticated as a user" do
    before do
      # reset token
      @token = nil
      # this call will now re-generate a new token
      AuthenticationInjector.token = token
    end

    it "can get a list of games" do
      must_be_allowed(:get, "/v1/public/games")
    end

    #  - You can promote a user who is yourself to become a developer when authenticated
    it "can promote yourself to become a developer" do
      wont_be_a_developer(@yourself)
      must_be_allowed(:post, "/v1/developers/#{@yourself}")
      must_be_a_developer(@yourself)
    end

    #  - You cannot promote any other user to become a developer without system privileges
    it "cannot promote anyone else to become a developer" do
      must_be_forbidden(:post, "/v1/developers/#{@someone_else}")
      wont_be_a_developer(@someone_else)
    end

    #  - You can demote a user who is yourself from being a developer when authenticated
    it "can demote yourself from being a developer" do
      make_developer!(@yourself)

      must_be_allowed(:delete, "/v1/developers/#{@yourself}")
      wont_be_a_developer(@yourself)
    end

    #  - You cannot demote any other user from being a developer without system privileges
    it "cannot demote anyone else from being a developer" do
      make_developer!(@someone_else)

      must_be_forbidden(:delete, "/v1/developers/#{@someone_else}")
      must_be_a_developer(@someone_else)
    end

    #  - You can list games of a developer who is yourself when authenticated
    it "can list games of yourself" do
      make_developer!(@yourself)
      must_be_allowed(:get, "/v1/developers/#{@yourself}/games")
    end

    #  - You cannot list games of any other developer without system privileges
    it "cannot list games of anyone else" do
      make_developer!(@someone_else)
      must_be_forbidden(:get, "/v1/developers/#{@someone_else}/games")
    end

    #  - You can add a game with yourself as a developer when authenticated
    it "can add a game with yourself as a developer" do
      games_of_a_developer(@yourself).must_be_empty
      make_developer!(@yourself)
      must_be_allowed(:post, "/v1/games", JSON.dump(@game_options))
      games_of_a_developer(@yourself).length.must_equal 1
    end

    #  - You cannot add a game with any other developer than yourself without system privilges
    it "cannot add a game with anyone but you developing it" do
      options = @game_options.clone
      options[:developers] = [@someone_else]
      make_developer!(@someone_else)
      make_developer!(@yourself)

      games_of_a_developer(@someone_else).must_be_empty
      must_be_forbidden(:post, "/v1/games", JSON.dump(options))
      games_of_a_developer(@someone_else).must_be_empty

      options[:developers] = [@yourself, @someone_else]
      must_be_forbidden(:post, "/v1/games", JSON.dump(options))
      games_of_a_developer(@yourself).must_be_empty
    end

    #  - You cannot change the list of developers of a game which you are a developer of without system privileges
    it "cannot add a developer to a game" do
      game = create_game!(@game_options)
      make_developer!(@someone_else)
      must_be_forbidden(:post, "/v1/games/#{game}/developers/#{@someone_else}")
      must_be_developer_of_game(@yourself, game)
      wont_be_developer_of_game(@someone_else, game)

      game = create_game!(@game_options.merge(developers: [@someone_else]))
      make_developer!(@yourself)
      must_be_forbidden(:post, "/v1/games/#{game}/developers/#{@yourself}")
      wont_be_developer_of_game(@yourself, game)
      must_be_developer_of_game(@someone_else, game)
    end

    #  - You cannot change the list of developers of a game which you are a developer of without system privileges
    it "cannot remove a developer from a game" do
      game = create_game!(@game_options)
      make_developer_of_game!(@someone_else, game)

      must_be_forbidden(:delete, "/v1/games/#{game}/developers/#{@yourself}")
      must_be_developer_of_game(@yourself, game)
      must_be_developer_of_game(@someone_else, game)
    end

    #  - You cannot change the list of developers of a game which you are a developer of without system privileges
    it "cannot change a game" do
      game = create_game!(@game_options)
      make_developer!(@someone_else)
      must_be_forbidden(:put, "/v1/games/#{game}", JSON.dump(developers: [@yourself, @someone_else]))
      must_be_developer_of_game(@yourself, game)
      wont_be_developer_of_game(@someone_else, game)
    end


    #  - You can delete a game which you are a developer of when authenticated
    it "can delete a game you develop" do
      game = create_game!(@game_options)
      must_be_allowed(:delete, "/v1/games/#{game}")
      game_wont_exist(game)
    end

    #  - You cannot delete any other game without system privileges
    it "cannot delete a game anyone else develops" do
      make_developer!(@someone_else)
      game = create_game!(@game_options.merge(developers: [@someone_else]))
      must_be_forbidden(:delete, "/v1/games/#{game}")
      game_must_exist(game)
    end

    #  - You can change the configuration of a game which you are a developer of when authenticated
    it "can change a game you develop" do
      game = create_game!(@game_options)
      must_be_allowed(:put, "/v1/games/#{game}", JSON.dump(name: "Updated game"))
      get_game(game)['name'].must_equal 'Updated game'
    end

    #  - You cannot change the configuration of any other game without system privileges
    it "cannot change a game anyone else develops" do
      make_developer!(@someone_else)
      game = create_game!(@game_options.merge(developers: [@someone_else]))
      must_be_forbidden(:put, "/v1/games/#{game}", JSON.dump(name: "Updated game"))
      get_game(game)['name'].wont_equal 'Updated game'
    end

    #  - You can retrieve the configuration of a game that you are a developer of when authenticated
    it "can retrieve private game information of a game you develop" do
      game = create_game!(@game_options)
      must_be_allowed(:get, "/v1/games/#{game}")
    end

    #  - You cannot retrieve the configuration of any other game without system privileges
    it "cannot retrieve private game information of a game someone else develops" do
      make_developer!(@someone_else)
      game = create_game!(@game_options.merge(developers: [@someone_else]))
      must_be_forbidden(:get, "/v1/games/#{game}")
    end
  end

  describe "authenticated as an app with system level privileges" do
    before do
      AuthenticationInjector.token = APP_TOKEN
    end

    it "can get a list of games" do
      must_be_allowed(:get, "/v1/public/games")
    end

    it "can promote anyone to become a developer" do
      wont_be_a_developer(@someone_else)
      must_be_allowed(:post, "/v1/developers/#{@someone_else}")
      must_be_a_developer(@someone_else)
    end

    it "can demote anyone from being a developer" do
      make_developer!(@someone_else)

      must_be_allowed(:delete, "/v1/developers/#{@someone_else}")
      wont_be_a_developer(@someone_else)
    end

    it "can list games of anyone" do
      make_developer!(@someone_else)
      must_be_allowed(:get, "/v1/developers/#{@someone_else}/games")
    end

    it "can add a game with anyone developing it" do
      options = @game_options.clone
      options[:developers] = [@someone_else]
      make_developer!(@someone_else)
      make_developer!(@yourself)

      games_of_a_developer(@yourself).must_be_empty
      must_be_allowed(:post, "/v1/games", JSON.dump(options))
      games_of_a_developer(@someone_else).wont_be_empty
      game = games_of_a_developer(@someone_else).first
      client.delete "/v1/games/#{game}"

      options[:developers] = [@yourself, @someone_else]
      must_be_allowed(:post, "/v1/games", JSON.dump(options))
      games_of_a_developer(@yourself).wont_be_empty
      games_of_a_developer(@someone_else).wont_be_empty
    end

    it "can add a developer to a game" do
      game = create_game!(@game_options)
      make_developer!(@someone_else)
      must_be_allowed(:post, "/v1/games/#{game}/developers/#{@someone_else}")
      must_be_developer_of_game(@yourself, game)
      must_be_developer_of_game(@someone_else, game)

      game = create_game!(@game_options.merge(developers: [@someone_else]))
      make_developer!(@yourself)
      must_be_allowed(:post, "/v1/games/#{game}/developers/#{@yourself}")
      must_be_developer_of_game(@yourself, game)
      must_be_developer_of_game(@someone_else, game)
    end

    it "can remove a developer from a game" do
      game = create_game!(@game_options)
      make_developer_of_game!(@someone_else, game)

      must_be_allowed(:delete, "/v1/games/#{game}/developers/#{@yourself}")
      wont_be_developer_of_game(@yourself, game)
      must_be_developer_of_game(@someone_else, game)
    end

    it "can change a game" do
      game = create_game!(@game_options)
      make_developer!(@someone_else)
      must_be_allowed(:put, "/v1/games/#{game}", JSON.dump(developers: [@yourself, @someone_else]))
      must_be_developer_of_game(@yourself, game)
      must_be_developer_of_game(@someone_else, game)
    end

    it "can delete any game" do
      make_developer!(@someone_else)
      game = create_game!(@game_options.merge(developers: [@someone_else]))
      must_be_allowed(:delete, "/v1/games/#{game}")
      game_wont_exist(game)
    end

    it "can change a game anyone develops" do
      make_developer!(@someone_else)
      game = create_game!(@game_options.merge(developers: [@someone_else]))
      must_be_allowed(:put, "/v1/games/#{game}", JSON.dump(name: "Updated game"))
      get_game(game)['name'].must_equal 'Updated game'
    end

    it "cann retrieve private game information of any game" do
      make_developer!(@someone_else)
      game = create_game!(@game_options.merge(developers: [@someone_else]))
      must_be_allowed(:get, "/v1/games/#{game}")
    end
  end
end