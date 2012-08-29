module Devcenter::Backend
  module GameType
    class Html5 < Base
      def valid?
        @configuration['url'] && @configuration['url'] !~ /^\s*$/
      end
    end
  end
end
