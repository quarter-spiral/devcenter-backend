require 'devcenter-backend/game_type/base'
require 'devcenter-backend/game_type/initial'
require 'devcenter-backend/game_type/html5'
require 'devcenter-backend/game_type/flash'

module Devcenter::Backend
  module GameType
    def self.valid?(game)
      game_type = game_type_for(game)
      raise Error::ValidationError.new("Game type not found!") unless game_type
      game_type.valid?
    end

    protected
    def self.game_type_for(game)
      configuration = game.configuration
      game_type = configuration['type']
      raise Error::ValidationError.new("No game type set!") unless game_type
      Devcenter::Backend::GameType.const_get(Utils.camelize_string(game_type)).new(game)
    rescue NameError => e
      nil
    end
  end
end
