module Devcenter::Backend
  class Game
    MASS_ASSIGNABLE_ATTRIBUTES = [:name, :description, :screenshots, :configuration, :developer_configuration, :venues, :category, :credits, :credits_url]

    attr_accessor :uuid, :name, :description, :category, :credits
    attr_writer :configuration, :screenshots, :developer_configuration
    attr_reader :original_attributes, :token, :secret, :credits_url

    def self.create(token, params)
      developers = params.delete :developers

      raise Error::BaseError.new("Game cannot be created without a category") unless params[:category]

      game = new(token, params.merge(new_game: true))

      ensure_enough_developers!(developers)
      ensure_game_is_valid!(game)

      game.uuid = connection.datastore.create(token, {'game' => game.to_hash(no_graph: true)})
      game.save
      unless game.adjust_developers(developers)
        game.destroy
        raise Error::BaseError.new("Can't create game with this developer list!")
      end
      connection.graph.add_role(game.uuid, token, 'game')
      game.mark_as_saved!
      game
    end

    def initialize(token, params = {})
      @token = token
      params = params.clone
      @new_game = params.delete(:new_game)
      params.delete(:developers)
      raw_update_from_hash(params)

      #TODO: Remove rolling migration
      self.category = 'None' unless category

      generate_secret! unless secret

      @original_attributes = to_hash(no_graph: true)
    end

    def self.find(uuid, token)
      data = connection.datastore.get(uuid, token)
      raise Error::NotFoundError.new("Game #{uuid} not found!") unless data
      raise Error::BaseError.new("Entity not a game (#{uuid})") unless data['game']

      game = new(token, data['game'])
      game.uuid = uuid
      game
    end

    def self.find_batch(uuids, token)
      games = connection.datastore.get(uuids, token)
      return {} unless games
      Hash[games.map do |uuid, data|
        next unless data['game']
        game = new(token, data['game'])
        game.uuid = uuid
        [uuid, game]
      end.compact]
    end

    def self.all(token, options = {})
      game_uuids = options[:uuids] || connection.graph.uuids_by_role(token, 'game')

      find_batch(game_uuids, token).values
    end

    def destroy
      connection = self.class.connection
      connection.datastore.set(uuid, token, {})
      connection.graph.delete_entity(uuid, token)
    end

    def to_hash(options = {})
      hash = {uuid: uuid, name: name, description: description, secret: secret, configuration: configuration, screenshots: screenshots, developer_configuration: developer_configuration, category: category, credits: credits, credits_url: credits_url}

      hash[:developers] = developers unless options[:no_graph]
      hash[:venues] = options[:no_graph] ? venues : venues_with_computed_config
      hash
    end

    def public_information
      ready_venues = venues_with_computed_config.select {|venue, config| config['enabled'] && config['computed']['ready']}.map {|venue, config| venue}
      info = {'uuid' => uuid, 'name' => name, 'description' => description, 'screenshots' => screenshots, 'venues' => ready_venues, 'category' => category, 'credits' => credits, 'credits_url' => credits_url}

      if venues_with_computed_config['embedded'] && venues_with_computed_config['embedded']['computed'] && venues_with_computed_config['embedded']['computed']['code']
        info['embed'] = venues_with_computed_config['embedded']['computed']['code']
      end
      info
    end

    def adjust_developers(new_developers)
      old_developers = developers.clone
      developers_to_create = new_developers - old_developers
      developers_to_delete = old_developers - new_developers

      developers_to_create.each do |developer|
        add_developer(developer)
      end
      developers_to_delete.each do |developer|
        remove_developer(developer)
      end
    rescue Service::Client::ServiceError => e
      adjust_developers(old_developers) and return false if e.error =~ /^Relation:.*is invalid!$/
      raise e
    end

    def update_from_hash(hash)
      unassignable_keys = hash.keys.select {|k| !MASS_ASSIGNABLE_ATTRIBUTES.include?(k.to_sym)}
      raise Error::ValidationError.new("Can not mass update: #{unassignable_keys.join(',')}!") unless unassignable_keys.empty?
      raw_update_from_hash(hash)
    end

    def add_developer(developer)
      self.class.connection.graph.add_relationship(developer, uuid, token, 'develops')
    end

    def remove_developer(developer)
      self.class.connection.graph.remove_relationship(developer, uuid, token, 'develops')
    end

    def valid?
      raise Error::ValidationError.new("Games must have a name!") unless name.to_s !~ /^\s*$/
      raise Error::ValidationError.new("Game must have a description!") unless description.to_s !~ /^\s*$/
      raise Error::ValidationError.new("Game must have a category!") unless category.to_s !~ /^\s*$/
      raise Error::ValidationError.new("Game configuration invalid!") unless GameType.valid?(self)
      raise Error::ValidationError.new("Game's credits URL must be a http or https URL") if credits_url && credits_url !~ /^http(s|):\/\//

      Venue.validate_game(self)
    end

    def new_game?
      @new_game
    end

    def mark_as_saved!
      @new_game = false
    end

    def save
      self.class.ensure_game_is_valid!(self)
      self.class.connection.datastore.set(uuid, token, {'game' => to_hash(no_graph: true)})
    end

    def developers
      return [] unless uuid
      self.class.connection.graph.list_related_entities(uuid, token, 'develops', direction: 'incoming')
    end

    def configuration
      @configuration || {}
    end

    def developer_configuration
      @developer_configuration || {}
    end

    def screenshots
      @screenshots || []
    end

    def venues
      @venues ||= {}
    end

    def venues_with_computed_config
      Hash[@venues.map do |name, config|
        venue = Venue.venue_for(name, config, self)
        [name, venue.computed_config]
      end]
    end

    def venues=(new_venues)
      new_venues.each do |venue, config|
        venues[venue] = config
      end
    end

    def credits_url=(new_credits_url)
      if new_credits_url =~ /^\s*$/
        @credits_url = nil
      else
        @credits_url = new_credits_url
      end
    end

    protected
    def raw_update_from_hash(hash)
      hash.each do |key, value|
        value = value.to_hash if value.kind_of?(Hash)
        self.send("#{key}=", value)
      end
    end

    def generate_secret!
      @secret = File.read('/dev/urandom', 32).bytes.map {|e| (e.ord % 64 + 63).chr}.join('')
    end

    def secret=(secret)
      @secret = secret
    end

    def self.connection
      @connection ||= Connection.create
    end

    def self.ensure_enough_developers!(developers)
      raise Error::BaseError.new("Games must have at least one developer!") if !developers || developers.empty?
    end

    def self.ensure_game_is_valid!(game)
      # game validation raises errors from within itself
      game.valid?
    end
  end
end
