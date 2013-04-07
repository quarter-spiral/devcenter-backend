require_relative '../spec_helper.rb'
require_relative '../request_spec_helper.rb'

require 'json'
require 'uuid'

describe Devcenter::Backend::API do
  before do
    @connection = ::Devcenter::Backend::Connection.create

    existing_games = @connection.graph.uuids_by_role(APP_TOKEN, 'game')
    existing_games.each {|uuid| @connection.graph.delete_entity(uuid, APP_TOKEN)}

    @developer = @connection.auth.token_owner(token)['uuid']
    client.post("/v1/developers/#{@developer}", "Authorization" => "Bearer #{APP_TOKEN}")

    @game_data = {
      "name" => "Test Game",
      "description" => "A good game",
      "developers" => [@developer],
      "configuration" => {type: "html5", url: "http://example.com/game"},
      "category" => "Jump n run",
      "venues" => {
        "facebook" => {
          "enabled" => true,
          "app-id" => "119766961504555",
          "app-secret" => "0b40a9fb11f5f42f1c48835ea8eac220"
        },
        "spiral-galaxy" => {
          "enabled" => true
        }
      }
    }

    response = client.post "/v1/games", {"Authorization" => "Bearer #{APP_TOKEN}"}, JSON.dump(@game_data)
    response.status.must_equal 201
    @game_uuid = JSON.parse(response.body)['uuid']

    response = client.post "/v1/games", {"Authorization" => "Bearer #{APP_TOKEN}"}, JSON.dump(@game_data.merge("name" => "Test Game 2"))
    response.status.must_equal 201
    @game_uuid2 = JSON.parse(response.body)['uuid']

    @player1 = UUID.new.generate
    @player2 = UUID.new.generate
    @player3 = UUID.new.generate

    playercenter_client = Playercenter::Client.new('http://example.com')
    playercenter_client.client.raw.adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, Playercenter::Backend::API.new])
    playercenter_client.register_player(@player1, @game_uuid, 'facebook', APP_TOKEN)
    playercenter_client.register_player(@player1, @game_uuid, 'spiral-galaxy', APP_TOKEN)
    playercenter_client.register_player(@player1, @game_uuid, 'facebook', APP_TOKEN)
    playercenter_client.register_player(@player2, @game_uuid2, 'facebook', APP_TOKEN)
    playercenter_client.register_player(@player3, @game_uuid, 'spiral-galaxy', APP_TOKEN)
    playercenter_client.register_player(@player3, @game_uuid2, 'spiral-galaxy', APP_TOKEN)

    AuthenticationInjector.token = APP_TOKEN
  end

  after do
    client.delete "/v1/games/#{@game_uuid}", {"Authorization" => "Bearer #{APP_TOKEN}"}
    client.delete "/v1/games/#{@game_uuid2}", {"Authorization" => "Bearer #{APP_TOKEN}"}

    AuthenticationInjector.reset!
  end

  it "has the right insights" do
    10.times do
      @connection.tracking.game.track_player(@game_uuid, "spiral-galaxy", blocking: true)
    end

    2.times do
      @connection.tracking.game.track_player(@game_uuid, "facebook", blocking: true)
    end

    7.times do
      @connection.tracking.game.track_logged_in_player(@game_uuid, "facebook", @player1, blocking: true)
    end

    13.times do
      @connection.tracking.game.track_player(@game_uuid2, "facebook", blocking: true)
    end

    response = client.get "/v1/games/#{@game_uuid}/insights"
    response.status.must_equal 200
    insights = JSON.parse(response.body)
    insights.keys.size.must_equal 1
    insights[@game_uuid].keys.size.must_equal 2

    insights[@game_uuid]["players"].must_equal({
      "overall" => 2,
      "facebook" => 1,
      "spiral-galaxy" => 2,
      "embedded" => 0
    })

    insights[@game_uuid]["players"].must_equal({
      "overall" => 2,
      "facebook" => 1,
      "spiral-galaxy" => 2,
      "embedded" => 0
    })

    insights[@game_uuid]["impressions"].keys.size.must_equal 4
    insights[@game_uuid]["impressions"]["overall"]["logged_in"]["total"].must_equal 7
    insights[@game_uuid]["impressions"]["spiral-galaxy"]["logged_in"]["total"].must_equal 0
    insights[@game_uuid]["impressions"]["embedded"]["logged_in"]["total"].must_equal 0
    insights[@game_uuid]["impressions"]["facebook"]["logged_in"]["total"].must_equal 7
    insights[@game_uuid]["impressions"]["overall"]["anonymous"]["total"].must_equal 12
    insights[@game_uuid]["impressions"]["spiral-galaxy"]["anonymous"]["total"].must_equal 10
    insights[@game_uuid]["impressions"]["embedded"]["anonymous"]["total"].must_equal 0
    insights[@game_uuid]["impressions"]["facebook"]["anonymous"]["total"].must_equal 2
  end
end
