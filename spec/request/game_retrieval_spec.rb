require_relative '../spec_helper.rb'
require_relative '../request_spec_helper.rb'

require 'json'
require 'uuid'

describe Devcenter::Backend::API do
  before do
    @connection = ::Devcenter::Backend::Connection.create
  end

  describe "authenticated" do
    describe "with a game" do
      before do
        existing_games = @connection.graph.uuids_by_role(APP_TOKEN, 'game')
        existing_games.each {|uuid| @connection.graph.delete_entity(uuid, APP_TOKEN)}

        @developer1 = @connection.auth.token_owner(token)['uuid']
        client.post("/v1/developers/#{@developer1}", "Authorization" => "Bearer #{APP_TOKEN}")

        @developer2 = @connection.auth.token_owner(
            @connection.auth.venue_token(APP_TOKEN, 'facebook', "name" => "Peter Smith", "venue-id" => "365464326")
        )['uuid']
        client.post("/v1/developers/#{@developer2}", "Authorization" => "Bearer #{APP_TOKEN}")

        @game_data1 = {
          'name' => "Test Game",
          'description' => "A good game",
          'developers' => [@developer1],
          'configuration' => {type: "html5", url: "http://example.com/game"}
        }

        response = client.post "/v1/games", {"Authorization" => "Bearer #{APP_TOKEN}"}, JSON.dump(@game_data1)
        response.status.must_equal 201
        @game_uuid1 = JSON.parse(response.body)['uuid']

        @game_data2 = {
          'name' => "Second Game",
          'description' => "Wow what a game",
          'developers' => [@developer2],
          'configuration' => {type: "html5", url: "http://example.com/game2"}
        }

        response = client.post "/v1/games", {"Authorization" => "Bearer #{APP_TOKEN}"}, JSON.dump(@game_data2)
        response.status.must_equal 201
        @game_uuid2 = JSON.parse(response.body)['uuid']

        @game_data3 = {
          'name' => "Third Game",
          'description' => "Cool game",
          'developers' => [@developer1],
          'configuration' => {type: "html5", url: "http://example.com/game3"}
        }

        response = client.post "/v1/games", {"Authorization" => "Bearer #{APP_TOKEN}"}, JSON.dump(@game_data3)
        response.status.must_equal 201
        @game_uuid3 = JSON.parse(response.body)['uuid']

      end

      after do
        client.delete "/v1/games/#{@game_uuid1}", {"Authorization" => "Bearer #{APP_TOKEN}"}
        client.delete "/v1/games/#{@game_uuid2}", {"Authorization" => "Bearer #{APP_TOKEN}"}
        client.delete "/v1/games/#{@game_uuid3}", {"Authorization" => "Bearer #{APP_TOKEN}"}
      end

      it "can retrieve a list of all games" do
        response = client.get "/v1/public/games"
        response.status.must_equal 200

        games = JSON.parse(response.body)['games']
        games.size.must_equal 3

        game1 = games.detect {|g| g['uuid'] == @game_uuid1}
        game1['name'].must_equal @game_data1['name']
        game1['description'].must_equal @game_data1['description']

        game2 = games.detect {|g| g['uuid'] == @game_uuid2}
        game2['name'].must_equal @game_data2['name']
        game2['description'].must_equal @game_data2['description']

        game3 = games.detect {|g| g['uuid'] == @game_uuid3}
        game3['name'].must_equal @game_data3['name']
        game3['description'].must_equal @game_data3['description']
      end
    end
  end
end
