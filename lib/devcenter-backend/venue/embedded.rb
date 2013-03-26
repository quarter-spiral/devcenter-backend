module Devcenter::Backend
  module Venue
    class Embedded < Base
      def venue_id
        'embedded'
      end

      def computed_config
        computed_config = super
        if computed_config['enabled']
          size = game.configuration['sizes'].first

          computed_config['computed']['code'] = %Q{<iframe width="#{size['width']}" height="#{size['height']}" src="#{ENV['QS_CANVAS_APP_URL']}/v1/games/#{game.uuid}/embedded" style="padding:0px; margin:0px; background-color:#000; border-width:0px;" frameborder="0" align="top"></iframe>}
        end
        computed_config
      end
    end
  end
end
