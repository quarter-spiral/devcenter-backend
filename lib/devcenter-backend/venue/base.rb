module Devcenter::Backend
  module Venue
    class Base
      attr_reader :game

      def initialize(game)
        @game = game
      end

      def valid?
        true
      end
    end
  end
end
