require 'devcenter-backend/game_type/base'
require 'devcenter-backend/game_type/html5'
require 'devcenter-backend/game_type/flash'

module Devcenter::Backend
  module GameType
    def self.valid?(configuration)
      game_type = game_type_for(configuration)
      raise ValidationError.new("Game type not found!") unless game_type
      game_type.valid?
    end

    protected
    def self.game_type_for(configuration)
      game_type = configuration['type']
      raise ValidationError.new("No game type set!") unless game_type
      Devcenter::Backend::GameType.const_get(camelize_string(game_type)).new(configuration)
    rescue NameError => e
      nil
    end

    def self.camelize_string(str)
      str.sub(/^[a-z\d]*/) { $&.capitalize }.gsub(/(?:_|(\/))([a-z\d]*)/i) {$2.capitalize}
    end
  end
end
