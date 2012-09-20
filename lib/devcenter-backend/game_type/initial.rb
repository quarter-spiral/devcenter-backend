module Devcenter::Backend
  module GameType
    class Initial < Base
      def valid?
        game.original_attributes[:configuration]['type'] == 'initial' || game.new_game?
      end
    end
  end
end
