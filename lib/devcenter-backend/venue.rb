require 'devcenter-backend/venue/base'
require 'devcenter-backend/venue/facebook'
require 'devcenter-backend/venue/spiral_galaxy'

module Devcenter::Backend
  module Venue
    def self.validate_game(game)
      venues = game.venues

      venues.each do |venue_name, config|
        raise Error::ValidationError.new("Invalid data for venue '#{venue_name}'! Provide a hash.") unless config.kind_of?(Hash)
        raise Error::ValidationError.new("Data for venue '#{venue_name}' must include the 'enabled' key!") unless config.keys.include?('enabled')

        venue = venue_for(venue_name, config, game)
        raise Error::ValidationError.new("Venue '#{venue_name}' does not exist!") unless venue
        raise Error::ValidationError.new("Vanue '#{venue_name}' invalid!") unless venue.valid?
      end
    end

    def self.venue_for(venue, config, game)
      Devcenter::Backend::Venue.const_get(Utils.camelize_string(venue)).new(config, game)
    rescue NameError => e
      nil
    end
  end
end
