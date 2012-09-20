module Devcenter::Backend
  module GameType
    class Html5 < Base
      def valid?
        game.configuration['url'] && game.configuration['url'] !~ /^\s*$/
      end
    end
  end
end
