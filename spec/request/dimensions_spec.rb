require_relative '../spec_helper.rb'
require_relative '../request_spec_helper.rb'

require 'json'
require 'uuid'
require 'uri'

describe Devcenter::Backend::API do
  before do
    @entity1 = UUID.new.generate

    @connection = ::Devcenter::Backend::Connection.create
  end

  describe "authenticated" do
    before do
      AuthenticationInjector.token = token
    end

    after do
      AuthenticationInjector.reset!
    end

    describe "sizes" do
      before do
        client.post "/v1/developers/#{@entity1}"

        response = client.post "/v1/games", {}, JSON.dump(name: "Test Game", description: "A good game", developers: [@entity1], configuration: {type: "html5", url: "http://example.com/game"}, category: 'Jump n Run')

        @default_sizes = [{"width" => 600, "height" => 400}]

        config = JSON.parse(response.body)
        config['configuration']['sizes'].must_equal @default_sizes
        (!config['configuration']['fluid-size']).must_equal(true)
        @game = config['uuid']
      end

      it "comes with a default size when none is set" do
        response = client.get "/v1/games/#{@game}"
        config = JSON.parse(response.body)
        config['configuration']['sizes'].must_equal @default_sizes
        (!config['configuration']['fluid-size']).must_equal(true)
      end

      it "can save new sizes" do
        response = client.put "/v1/games/#{@game}", {}, JSON.dump(configuration: {type: "html5", url: "http://example.com/game", sizes: [{"width" => 480, "height" => 100}, {"width" => 200, "height" => 200}]})
        config = JSON.parse(response.body)
        game = config['uuid']
        config['configuration']['sizes'].must_equal [{"width" => 480, "height" => 100}, {"width" => 200, "height" => 200}]
        response = client.get "/v1/games/#{game}"
        config = JSON.parse(response.body)
        config['configuration']['sizes'].must_equal [{"width" => 480, "height" => 100}, {"width" => 200, "height" => 200}]
      end

      it "fall back to defaults when saving an empty sizes array" do
        response = client.put "/v1/games/#{@game}", {}, JSON.dump(configuration: {type: "html5", url: "http://example.com/game", sizes: []})
        config = JSON.parse(response.body)
        game = config['uuid']
        config['configuration']['sizes'].must_equal @default_sizes
        response = client.get "/v1/games/#{game}"
        config = JSON.parse(response.body)
        config['configuration']['sizes'].must_equal @default_sizes
      end

      it "fall back to defaults when saving a null sizes array" do
        response = client.put "/v1/games/#{@game}", {}, JSON.dump(configuration: {type: "html5", url: "http://example.com/game", sizes: nil})
        config = JSON.parse(response.body)
        game = config['uuid']
        config['configuration']['sizes'].must_equal @default_sizes
        response = client.get "/v1/games/#{game}"
        config = JSON.parse(response.body)
        config['configuration']['sizes'].must_equal @default_sizes
      end

      it "drops bullshit sizes" do
        sizes_with_some_bullshit = [{"width" => 600, "height" => "400"}, {"width" => "600", "height" => 400}, {"width" => 600}, {"height" => 400}, {"width" => 300, "height" => 200}, {"width" => "23sdfsdf", "height" => "45"}, {"width" => "453", "height" => "45ads"}, {"width" => 200, "height" => 400}, {"width" => -1, "height" => 200}, {"width" => "", "height" => 100}, {"width" => 100, "height" => ""}]
        valid_sizes = [{"width" => 300, "height" => 200}, {"width" => 200, "height" => 400}]

        response = client.put "/v1/games/#{@game}", {}, JSON.dump(configuration: {type: "html5", url: "http://example.com/game", sizes: sizes_with_some_bullshit})
        config = JSON.parse(response.body)
        game = config['uuid']
        config['configuration']['sizes'].must_equal valid_sizes
        response = client.get "/v1/games/#{game}"
        config = JSON.parse(response.body)
        config['configuration']['sizes'].must_equal valid_sizes
      end

      it "can be set to a fluid canvas" do
        response = client.put "/v1/games/#{@game}", {}, JSON.dump(configuration: {type: "html5", url: "http://example.com/game", 'fluid-size' => true})
        config = JSON.parse(response.body)
        game = config['uuid']
        config['configuration']['fluid-size'].must_equal true
        response = client.get "/v1/games/#{game}"
        config = JSON.parse(response.body)
        config['configuration']['fluid-size'].must_equal true

        response = client.put "/v1/games/#{@game}", {}, JSON.dump(configuration: {type: "html5", url: "http://example.com/game", 'fluid-size' => false})
        config = JSON.parse(response.body)
        game = config['uuid']
        config['configuration']['fluid-size'].must_equal false
        response = client.get "/v1/games/#{game}"
        config = JSON.parse(response.body)
        config['configuration']['fluid-size'].must_equal false
      end
    end
  end
end