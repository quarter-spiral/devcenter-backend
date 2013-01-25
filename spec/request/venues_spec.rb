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
      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'facebook' => {enabled: true}, 'spiral-galaxy' => {enabled: true}})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      config['venues']['facebook']['enabled'].must_equal(true)
      config['venues']['spiral-galaxy']['enabled'].must_equal(true)
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

        client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'spiral-galaxy' => {enabled: false}})
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

    it "can add and remove spiral-galaxy venue" do
      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'spiral-galaxy' => {enabled: true}})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      config['venues']['spiral-galaxy']['enabled'].must_equal(true)

      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'spiral-galaxy' => {enabled: false}})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      config['venues']['spiral-galaxy']['enabled'].must_equal(false)

      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {facebook: {enabled: true}})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      config['venues']['spiral-galaxy']['enabled'].must_equal(false)
    end

    it "can add and remove embedded venue" do
      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'embedded' => {enabled: true}})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      config['venues']['embedded']['enabled'].must_equal(true)
      config['venues']['embedded']['computed']['code'].wont_be_nil
      config['venues']['embedded']['computed']['code'].must_equal %Q{<iframe width="600" height="600" src="#{ENV['QS_CANVAS_APP_URL']}/v1/games/#{@game}/embedded" style="padding:0px; margin:0px; background-color:#000; border-width:0px;" frameborder="0" align="top"></iframe>}

      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {'embedded' => {enabled: false}})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      config['venues']['embedded']['enabled'].must_equal(false)
      config['venues']['embedded']['computed']['code'].must_be_nil

      client.put "/v1/games/#{@game}", {}, JSON.dump(venues: {facebook: {enabled: true}})
      response = client.get "/v1/games/#{@game}"
      config = JSON.parse(response.body)
      config['venues']['embedded']['enabled'].must_equal(false)
      config['venues']['embedded']['computed']['code'].must_be_nil
    end
  end
end



