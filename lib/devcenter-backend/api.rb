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

          end

    post '/developers/:uuid' do
      connection.graph.add_role(params[:uuid], 'developer')
      ''
    end

    post '/games' do
      Game.create(params).to_hash
    end
  end
end
