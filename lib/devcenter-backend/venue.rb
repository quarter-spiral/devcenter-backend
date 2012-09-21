require 'devcenter-backend/venue/base'
require 'devcenter-backend/venue/facebook'
require 'devcenter-backend/venue/galaxy_spiral'

module Devcenter::Backend
  module Venue
    def self.normalize_game!(game)
      game.venues.each do |venue, enabled|
        game.venues[venue] == !!enabled
      end
    end

    def self.validate_game(game)
      venues = game.venues

      venues.each do |venue_name, enabled|
        raise ValidationError.new("Ilformed data for venue '#{venue_name}") if enabled != !!enabled

        venue = venue_for(venue_name, game)
        raise ValidationError.new("Venue '#{venue_name}' does not exist!") unless venue
        raise ValidationError.new("Vanue '#{venue_name}' invalid!") unless venue.valid?
      end
    end

    protected
    def self.venue_for(venue, game)
      Devcenter::Backend::Venue.const_get(Utils.camelize_string(venue)).new(game)
    rescue NameError => e
      nil
    end
  end
end
