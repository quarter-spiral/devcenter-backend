module Devcenter::Backend
  module GameType
    class Flash < Base
      def valid?
        game.configuration['url'] && game.configuration['url'] !~ /^\s*$/
      end
    end
  end
end

