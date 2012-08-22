require 'grape'

module Devcenter::Backend
  class API < ::Grape::API
    version 'v1', :using => :path, :vendor => 'quarter-spiral'

    format :json
    default_format :json

    rescue_from Devcenter::Backend::Error
    error_format :json

    helpers do
      def connection
        @connection ||= Connection.create
      end

      def get_game(uuid)
        data = connection.datastore.get(:public, uuid)
        error!("Game #{uuid} not found!", 404) unless data
        game = Game.new(data['game'])
        game.uuid = uuid
        game
      end
    end

    namespace '/developers' do
      post '/:uuid' do
        connection.graph.add_role(params[:uuid], 'developer')
        ''
      end

      delete '/:uuid' do
        connection.graph.remove_role(params[:uuid], 'developer')
        ''
      end

      get '/:uuid/games' do
        connection.graph.list_related_entities(params[:uuid], 'develops')
      end
    end

    namespace '/games' do
      post '/' do
        Game.create(params).to_hash
      end

      get '/:uuid' do
        uuid = params[:uuid]
        game = get_game(uuid)
        game.to_hash
      end

      put '/:uuid' do
        uuid = params[:uuid]
        game = get_game(uuid)

        game.name = params[:name] if params[:name]
        game.description = params[:description] if params[:description]
        game.screenshots = params[:screenshots] if params[:screenshots]
        game.configuration = params[:configuration].to_hash if params[:configuration]
        if params[:developers]
          error!("Can't create game with this developer list!", 403) unless game.adjust_developers(params[:developers])
        end
        game.save
        game.to_hash
      end

      delete '/:uuid' do
        game = Game.new
        game.uuid = params[:uuid]
        game.destroy
      end
    end
  end
end
