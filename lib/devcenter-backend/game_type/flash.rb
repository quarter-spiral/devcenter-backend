module Devcenter::Backend
  module GameType
    class Flash < Base
      def valid?
        @configuration['url'] && @configuration['url'] !~ /^\s*$/
      end
    end
  end
end

