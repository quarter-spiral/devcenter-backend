module UtilityMethods
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

  def payment_token(credit_card_number)
    Stripe::Token.create(
        :card => {
          :number => credit_card_number,
          :exp_month => 4,
          :exp_year => Time.now.year + 1,
          :cvc => 314
        }
    )['id']
  end

  def fake_payment_token
    payment_token("4242424242424242")
  end

  def subscribe!(token, game)
    options = {}
    options[:token] = token if token
    client.post "/v1/games/#{game}/subscription", {}, JSON.dump(options)
  end

  def unsubscribe!(game)
    client.delete "/v1/games/#{game}/subscription"
  end

  def must_have_subscription(game)
    with_system_level_privileges do
      get_game(game)['subscription'].must_equal true
    end
  end

  def wont_have_subscription(game)
    with_system_level_privileges do
      get_game(game)['subscription'].must_equal false
    end
  end
end