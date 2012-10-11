module Devcenter::Backend
  module Venue
    class Base
      attr_reader :config, :game

      def initialize(config, game)
        @config = config
        @game = game
      end

      def computed_config
        @config.merge('computed' => {'venue' => venue_id, 'ready' => ready?})
      end

      def valid?
        true
      end

      def ready?
        true
      end
    end
  end
end
