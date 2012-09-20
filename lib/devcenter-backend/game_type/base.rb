module Devcenter::Backend
  module GameType
    class Base
      attr_reader :game

      def initialize(game)
        @game = game
      end
    end
  end
end
