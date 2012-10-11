require_relative '../spec_helper.rb'
require_relative '../request_spec_helper.rb'

require 'json'
require 'uuid'

describe "Game Venues" do
  before do
    @entity1 = UUID.new.generate
    @entity2 = UUID.new.generate
  end

  describe "authenticated" do
    before do
      AuthenticationInjector.token = token

      @game_data = {name: "Test Game", description: "A good game", developers: [@entity1], configuration: {type: 'initial'}}
      client.post "/v1/developers/#{@entity1}"
      response = client.post "/v1/games", {}, JSON.dump(@game_data)
      @game = JSON.parse(response.body)['uuid']
    end

    after do
      AuthenticationInjector.reset!
    end

    it "doesn't allow bullshit venues" do
      response = client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'facebook' => {enabled: true}, 'bullshit' => {enabled: true}})
      response.status.wont_equal 200
      JSON.parse(response.body)['error'].wont_be_empty
    end

    it "can have multiple venues" do
      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'facebook' => {enabled: true}, 'galaxy-spiral' => {enabled: true}})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      config['venues']['facebook']['enabled'].must_equal(true)
      config['venues']['galaxy-spiral']['enabled'].must_equal(true)
    end

    describe 'facebook' do
      it "can add and remove the venue" do
        client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {facebook: {enabled: true}})
        response = client.get "/v1/games/#{@game}"
        config = JSON.parse(response.body)
        config['venues']['facebook']['enabled'].must_equal(true)

        client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {facebook: {enabled: false}})
        response = client.get "/v1/games/#{@game}"
        config = JSON.parse(response.body)
        config['venues']['facebook']['enabled'].must_equal(false)

        client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'galaxy-spiral' => {enabled: false}})
        response = client.get "/v1/games/#{@game}"
        config = JSON.parse(response.body)
        config['venues']['facebook']['enabled'].must_equal(false)
      end

      it "'s venue id is facebook" do
        client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {facebook: {enabled: true}})
        response = client.get "/v1/games/#{@game}"
        config = JSON.parse(response.body)
        config['venues']['facebook']['computed']['venue'].must_equal 'facebook'
      end

      it "is not ready unless app-id and app-secret are provided" do
        client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {facebook: {enabled: true}})
        response = client.get "/v1/games/#{@game}"
        config = JSON.parse(response.body)
        config['venues']['facebook']['computed']['ready'].must_equal false

        client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {facebook: {enabled: true, 'app-id' => '123'}})
        response = client.get "/v1/games/#{@game}"
        config = JSON.parse(response.body)
        config['venues']['facebook']['computed']['ready'].must_equal false

        client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {facebook: {enabled: true, 'app-id' => nil, 'app-secret' => '123'}})
        response = client.get "/v1/games/#{@game}"
        config = JSON.parse(response.body)
        config['venues']['facebook']['computed']['ready'].must_equal false

        client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {facebook: {enabled: true, 'app-id' => '456', 'app-secret' => '123'}})
        response = client.get "/v1/games/#{@game}"
        config = JSON.parse(response.body)
        config['venues']['facebook']['computed']['ready'].must_equal true
      end
    end

    it "can add and remove galaxy-spiral venue" do
      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'galaxy-spiral' => {enabled: true}})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      config['venues']['galaxy-spiral']['enabled'].must_equal(true)

      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'galaxy-spiral' => {enabled: false}})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      config['venues']['galaxy-spiral']['enabled'].must_equal(false)

      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {facebook: {enabled: true}})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      config['venues']['galaxy-spiral']['enabled'].must_equal(false)
    end
  end
end



