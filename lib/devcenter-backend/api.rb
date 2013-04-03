require 'grape'
require 'grape_newrelic'
require 'logger'

module Devcenter::Backend
  class API < ::Grape::API
    use GrapeNewrelic::Instrumenter
    version 'v1', :using => :path, :vendor => 'quarter-spiral'

    format :json
    default_format :json
    default_error_formatter :json

    class TokenStore
      def self.token(connection)
        @token ||= connection.auth.create_app_token(ENV['QS_OAUTH_CLIENT_ID'], ENV['QS_OAUTH_CLIENT_SECRET'])
      end

      def self.reset!
        @token = nil
      end
    end

    def self.logger
      Devcenter::Backend.logger
    end

    def self.warn(msg)
      logger.warn(msg)
    end

    rescue_from Devcenter::Backend::Error::BaseError do |e|
      API.logger.fatal "Error! #{e.class.name} - #{e.message}\n\t#{e.backtrace.join("\n\t")}"
      [500, {'Content-Type' => 'application/json'}, [JSON.dump(error: e.message)]]
    end
    rescue_from Devcenter::Backend::Error::ValidationError do |e|
      API.logger.warn "Error! #{e.class.name} - #{e.message}"
      [422, {'Content-Type' => 'application/json'}, [JSON.dump(error: e.message)]]
    end

    rescue_from Devcenter::Backend::Error::NotFoundError do |e|
      [404, {'Content-Type' => 'application/json'}, [JSON.dump(error: e.message)]]
    end

    helpers do
      def connection
        @connection ||= Connection.create
      end

      def sheer_params(*additional_fields_to_delete)
        sheer_params = params.clone
        ([:version, :route_info, :secret] + additional_fields_to_delete).each do |field|
          sheer_params.delete field
        end
        sheer_params
      end

      def token
        TokenStore.token(connection)
      end

      def try_twice_and_avoid_token_expiration
        yield
      rescue Service::Client::ServiceError => e
        raise e unless e.error == 'Unauthenticated'
        TokenStore.reset!
        yield
      end

      def last_game_update
        connection.cache.fetch('last_game_save') {-1}
      end

      def empty_body
        {}
      end

      def own_data?(uuid)
        @token_owner['uuid'] == uuid
      end

      def system_level_privileges?
        @token_owner['type'] == 'app'
      end

      def is_authorized_to_access?(uuid)
        system_level_privileges? || own_data?(uuid)
      end

      def prevent_access!
        error!('Unauthenticated', 403)
      end

      def owner_only!(uuid = params[:uuid])
        prevent_access! unless is_authorized_to_access?(uuid)
      end

      def system_privileges_only!
        prevent_access! unless system_level_privileges?
      end

      def developers_only!(game)
        prevent_access! unless system_level_privileges? || game.developers.include?(@token_owner['uuid'])
      end

      def retrieve_game(uuid)
        try_twice_and_avoid_token_expiration do
          Game.find(uuid, token)
        end
      end
    end

    before do
      header('Access-Control-Allow-Origin', request.env['HTTP_ORIGIN'] || '*')

      unless request.request_method == 'OPTIONS' || request.path_info =~ /^\/v1\/public\//
        prevent_access! unless request.env['HTTP_AUTHORIZATION']
        token = request.env['HTTP_AUTHORIZATION'].gsub(/^Bearer\s+/, '')
        @token_owner = connection.auth.token_owner(token)
        prevent_access! unless @token_owner
      end
    end

    options '*path' do
      header('Access-Control-Allow-Headers', 'origin, x-requested-with, content-type, accept, authorization')
      header('Access-Control-Allow-Methods', 'GET, PUT,OPTIONS, POST, DELETE')
      header('Access-Control-Max-Age', '1728000')
      empty_body
    end

    namespace '/public' do
      get '/games' do
        connection.cache.fetch(['public_games_list', last_game_update]) do
          uuids = params[:games]
          uuids = JSON.parse(uuids) if uuids && uuids.kind_of?(String)

          games = try_twice_and_avoid_token_expiration do
            Game.all(token, uuids: uuids)
          end

          {'games' => games.map {|game| game.public_information}}
        end
      end
    end

    namespace '/developers' do
      post '/:uuid' do
        owner_only!

        try_twice_and_avoid_token_expiration do
          connection.graph.add_role(params[:uuid], token, 'developer')
        end
        empty_body
      end

      delete '/:uuid' do
        owner_only!

        try_twice_and_avoid_token_expiration do
          connection.graph.remove_role(params[:uuid], token, 'developer')
        end
        empty_body
      end

      get '/:uuid/games' do
        owner_only!

        try_twice_and_avoid_token_expiration do
          game_uuids = connection.graph.list_related_entities(params[:uuid], token, 'develops')
          Hash[Game.find_batch(game_uuids, token).map {|uuid, game| [uuid, game.to_hash]}]
        end
      end
    end

    namespace '/games' do
      post '/' do
        prevent_access! unless system_level_privileges? || sheer_params[:developers] == [@token_owner['uuid']]

        try_twice_and_avoid_token_expiration do
          Game.create(token, sheer_params).to_hash
        end
      end

      post '/:uuid/developers/:developer_uuid' do
        system_privileges_only!

        uuid = params[:uuid]
        game = retrieve_game(uuid)
        game.add_developer(params[:developer_uuid])

        game.to_hash
      end

      delete '/:uuid/developers/:developer_uuid' do
        system_privileges_only!

        uuid = params[:uuid]
        game = retrieve_game(uuid)
        game.remove_developer(params[:developer_uuid])

        game.to_hash
      end

      get '/:uuid' do
        uuid = params[:uuid]
        game = retrieve_game(uuid)

        developers_only!(game)

        game.to_hash
      end

      put '/:uuid' do
        uuid = params[:uuid]
        game = retrieve_game(uuid)

        developers_only!(game)

        developers = params.delete(:developers)
        unless system_level_privileges?
          prevent_access! if developers && (game.developers != [@token_owner['uuid']] || developers != [@token_owner['uuid']])
        end

        game.update_from_hash(sheer_params(:uuid))

        if developers
          error!("Can't create game with this developer list!", 403) unless game.adjust_developers(developers)
        end

        game.save
        game.to_hash
      end

      delete '/:uuid' do
        game = retrieve_game(params[:uuid])

        developers_only!(game)

        game.destroy
      end
    end
  end
end
