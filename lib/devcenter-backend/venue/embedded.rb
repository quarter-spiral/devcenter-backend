module Devcenter::Backend
  module Venue
    class Embedded < Base
      HEIGHT_MARGIN = 140

      def venue_id
        'embedded'
      end

      def computed_config
        computed_config = super
        if computed_config['enabled']
          size = (game.configuration['sizes'] || []).first
          width = size['width'] || 600
          height = (size['height'] || 460).to_i + HEIGHT_MARGIN

          computed_config['computed']['code'] = %Q{<iframe width="#{width}" height="#{height}" src="#{ENV['QS_CANVAS_APP_URL']}/v1/games/#{game.uuid}/embedded" style="padding:0px; margin:0px; background-color:#000; border-width:0px;" frameborder="0" align="top"></iframe>}
        end
        computed_config
      end
    end
  end
end