module Devcenter::Backend
  module Venue
    class Base
      attr_reader :game

      def initialize(config, game)
        @config = config
        @game = game
      end

      def valid?
        true
      end
    end
  end
end
