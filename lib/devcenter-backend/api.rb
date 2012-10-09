require 'grape'

module Devcenter::Backend
  class API < ::Grape::API
    version 'v1', :using => :path, :vendor => 'quarter-spiral'

    format :json
    default_format :json

    rescue_from Devcenter::Backend::Error::BaseError
    rescue_from Devcenter::Backend::Error::ValidationError

    rescue_from Devcenter::Backend::Error::NotFoundError do |e|
      [404, {'Content-Type' => 'application/json'}, [JSON.dump(error: e.message)]]
    end

    error_format :json

    helpers do
      def connection
        @connection ||= Connection.create
      end

      def sheer_params(*additional_fields_to_delete)
        sheer_params = params.clone
        ([:version, :route_info] + additional_fields_to_delete).each do |field|
          sheer_params.delete field
        end
        sheer_params
      end
    end

    before do
      header('Access-Control-Allow-Origin', '*')

      error!('Unauthenticated', 403) unless request.env['HTTP_AUTHORIZATION']
      @token = request.env['HTTP_AUTHORIZATION'].gsub(/^Bearer\s+/, '')
      error!('Unauthenticated', 403) unless connection.auth.token_valid?(@token)
    end

    options '*path' do
      header('Access-Control-Allow-Headers', 'origin, x-requested-with, content-type, accept')
      header('Access-Control-Allow-Methods', 'GET, PUT,OPTIONS, POST, DELETE')
      header('Access-Control-Max-Age', '1728000')
      ""
    end

    namespace '/developers' do
      post '/:uuid' do
        connection.graph.add_role(params[:uuid], @token, 'developer')
        ''
      end

      delete '/:uuid' do
        connection.graph.remove_role(params[:uuid], @token, 'developer')
        ''
      end

      get '/:uuid/games' do
        connection.graph.list_related_entities(params[:uuid], @token, 'develops')
      end
    end

    namespace '/games' do
      post '/' do
        Game.create(@token, sheer_params).to_hash
      end

      post '/:uuid/developers/:developer_uuid' do
        uuid = params[:uuid]
        game = Game.find(uuid, @token)
        game.add_developer(params[:developer_uuid])

        game.to_hash
      end

      delete '/:uuid/developers/:developer_uuid' do
        uuid = params[:uuid]
        game = Game.find(uuid, @token)
        game.remove_developer(params[:developer_uuid])

        game.to_hash
      end

      get '/:uuid' do
        uuid = params[:uuid]
        game = Game.find(uuid, @token)
        game.to_hash
      end

      put '/:uuid' do
        uuid = params[:uuid]
        game = Game.find(uuid, @token)

        developers = params.delete(:developers)

        game.update_from_hash(sheer_params(:uuid))

        if developers
          error!("Can't create game with this developer list!", 403) unless game.adjust_developers(developers)
        end

        game.save
        game.to_hash
      end

      delete '/:uuid' do
        game = Game.new(@token)
        game.uuid = params[:uuid]
        game.destroy
      end
    end
  end
end
