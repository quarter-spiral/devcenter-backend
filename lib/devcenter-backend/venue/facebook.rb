module Devcenter::Backend
  module Venue
    class Facebook < Base
      def ready?
        !!(config['app-id'] && config['app-id'] !~ /^\s*$/ && config['app-secret'] && config['app-secret'] !~ /^\s*$/)
      end

      def venue_id
        'facebook'
      end
    end
  end
end
