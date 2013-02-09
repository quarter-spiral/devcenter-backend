require_relative '../spec_helper.rb'
require_relative '../request_spec_helper.rb'

require 'json'
require 'uuid'

def find_games(games, *uuids)
  games.select {|g| uuids.include?(g['uuid'])}
end

describe Devcenter::Backend::API do
  before do
    @connection = ::Devcenter::Backend::Connection.create
  end

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
        "name" => "Test Game",
        "description" => "A good game",
        "developers" => [@developer1],
        "configuration" => {type: "html5", url: "http://example.com/game"},
        "category" => "Jump n run",
        "venues" => {
          "facebook" => {
            "enabled" => true,
            "app-id" => "119766961504555",
            "app-secret" => "0b40a9fb11f5f42f1c48835ea8eac220"
          },
          "spiral-galaxy" => {
            "enabled" => false
          }
        }
      }

      response = client.post "/v1/games", {"Authorization" => "Bearer #{APP_TOKEN}"}, JSON.dump(@game_data1)
      response.status.must_equal 201
      @game_uuid1 = JSON.parse(response.body)['uuid']

      @game_data2 = {
        "name" => "Second Game",
        "description" => "Wow what a game",
        "developers" => [@developer2],
        "configuration" => {type: "html5", url: "http://example.com/game2"},
        "category" => "Jump n run",
        "venues" => {
          "facebook" => {
            "enabled" => true
          },
          "spiral-galaxy" => {
            "enabled" => true
          }
        }
      }

      response = client.post "/v1/games", {"Authorization" => "Bearer #{APP_TOKEN}"}, JSON.dump(@game_data2)
      response.status.must_equal 201
      @game_uuid2 = JSON.parse(response.body)['uuid']

      @game_data3 = {
        'name' => "Third Game",
        'description' => "Cool game",
        'developers' => [@developer1],
        'configuration' => {type: "html5", url: "http://example.com/game3"},
        "category" => "Jump n run",
        "venues" => {
          "facebook" => {
            "enabled" => true,
            "app-id" => "119766961504552",
            "app-secret" => "0b40a9fb11f5f42f1c48835ea8eac220"
          },
          "spiral-galaxy" => {
            "enabled" => true
          }
        }
      }

      response = client.post "/v1/games", {"Authorization" => "Bearer #{APP_TOKEN}"}, JSON.dump(@game_data3)
      response.status.must_equal 201
      @game_uuid3 = JSON.parse(response.body)['uuid']


      @game_data4 = {
        "name" => "Fourth Game",
        "description" => "A good game",
        "developers" => [@developer1],
        "configuration" => {type: "html5", url: "http://example.com/game"},
        "category" => "Jump n run",
        "venues" => {
        }
      }

      response = client.post "/v1/games", {"Authorization" => "Bearer #{APP_TOKEN}"}, JSON.dump(@game_data4)
      response.status.must_equal 201
      @game_uuid4 = JSON.parse(response.body)['uuid']

      @game_data5 = {
        "name" => "Fifth Game",
        "description" => "A good game",
        "developers" => [@developer1],
        "configuration" => {type: "html5", url: "http://example.com/game"},
        "category" => "Jump n run",
      }

      response = client.post "/v1/games", {"Authorization" => "Bearer #{APP_TOKEN}"}, JSON.dump(@game_data5)
      response.status.must_equal 201
      @game_uuid5 = JSON.parse(response.body)['uuid']
    end

    after do
      [@game_uuid1, @game_uuid2, @game_uuid3, @game_uuid4, @game_uuid5].each do |game|
        client.delete "/v1/games/#{game}", {"Authorization" => "Bearer #{APP_TOKEN}"}
      end
    end

    describe "with all games" do
      before do
        response = client.get "/v1/public/games"
        response.status.must_equal 200

        @games = JSON.parse(response.body)['games']
        @games.size.must_equal 5
        @game1, @game2, @game3, @game4, @game5 = find_games(@games, @game_uuid1, @game_uuid2, @game_uuid3, @game_uuid4, @game_uuid5)
      end

      it "can retrieve a list of all games" do
        @game1['name'].must_equal @game_data1['name']
        @game1['description'].must_equal @game_data1['description']

        @game2['name'].must_equal @game_data2['name']
        @game2['description'].must_equal @game_data2['description']

        @game3['name'].must_equal @game_data3['name']
        @game3['description'].must_equal @game_data3['description']

        @game4['name'].must_equal @game_data4['name']
        @game4['description'].must_equal @game_data4['description']

        @game5['name'].must_equal @game_data5['name']
        @game5['description'].must_equal @game_data5['description']
      end

      it "game information includes the enabled venues" do
        @game1['venues'].size.must_equal 1
        @game1['venues'].must_include 'facebook'

        @game2['venues'].size.must_equal 1
        @game2['venues'].must_include 'spiral-galaxy'

        @game3['venues'].size.must_equal 2
        @game3['venues'].must_include 'facebook'
        @game3['venues'].must_include 'spiral-galaxy'

        @game4['venues'].size.must_equal 0

        @game5['venues'].size.must_equal 0
      end
    end

    it "can retrieve a list of certain games" do
      response = client.get "/v1/public/games", {}, JSON.dump(games: [@game_uuid1, @game_uuid3])
      response.status.must_equal 200

      games = JSON.parse(response.body)['games']
      games.size.must_equal 2

      game1 = games.detect {|g| g['uuid'] == @game_uuid1}
      game1['name'].must_equal @game_data1['name']
      game1['description'].must_equal @game_data1['description']

      game3 = games.detect {|g| g['uuid'] == @game_uuid3}
      game3['name'].must_equal @game_data3['name']
      game3['description'].must_equal @game_data3['description']
    end
  end
end
