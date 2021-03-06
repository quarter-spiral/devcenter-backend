require 'uuid'

module Devcenter::Backend
  class Game
    MASS_ASSIGNABLE_ATTRIBUTES = [:name, :description, :screenshots, :configuration, :developer_configuration, :venues, :category, :credits, :credits_url]

    attr_accessor :uuid, :name, :description, :category, :credits, :end_of_subscription, :subscription_type, :subscription_customer_id
    attr_writer :screenshots, :developer_configuration
    attr_reader :original_attributes, :token, :secret, :credits_url

    def self.create(token, params)
      developers = params.delete :developers

      raise Error::BaseError.new("Game cannot be created without a category") unless params[:category]

      game = new(token, params.merge(new_game: true))

      ensure_enough_developers!(developers)
      ensure_game_is_valid!(game)

      game.uuid = UUID.new.generate
      connection.datastore.set(game.uuid, token, {'game' => game.to_hash(no_graph: true)})

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
      params.reject! {|k,v| [:developers, :subscription, :subscription_phasing_out].include?(k.to_sym)}

      raw_update_from_hash(params)

      #TODO: Remove rolling migration
      self.category = 'None' unless category

      generate_secret! unless secret

      @original_attributes = to_hash(no_graph: true)
    end

    def self.find(uuid, token)
      data = connection.datastore.get(uuid, token)

      raise Error::NotFoundError.new("Game #{uuid} not found!") if !data || data.empty?
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
      hash = {uuid: uuid, name: name, description: description, secret: secret, configuration: configuration, screenshots: screenshots, developer_configuration: developer_configuration, category: category, credits: credits, credits_url: credits_url, subscription: has_subscription?, subscription_phasing_out: has_subscription? && end_of_subscription}

      hash[:developers] = developers unless options[:no_graph]
      if options[:no_graph]
        hash.merge!(
            venues: venues,
            end_of_subscription: end_of_subscription,
            subscription_type: subscription_type,
            subscription_customer_id: subscription_customer_id
        )
      else

        hash[:venues] = venues_with_computed_config
      end

      hash
    end

    def public_information
      ready_venues = venues_with_computed_config.select {|venue, config| config['enabled'] && config['computed']['ready']}.map {|venue, config| venue}
      info = {'uuid' => uuid, 'name' => name, 'description' => description, 'screenshots' => screenshots, 'venues' => ready_venues, 'category' => category, 'credits' => credits, 'credits_url' => credits_url, 'subscription' => has_subscription?}

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
      hash = hash.reject {|k, v| !MASS_ASSIGNABLE_ATTRIBUTES.include?(k.to_sym)}
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
      self.class.connection.cache.set('last_game_save', Time.now.to_i)
      self.class.connection.datastore.set(uuid, token, {'game' => to_hash(no_graph: true)})
    end

    def developers
      return [] unless uuid
      self.class.connection.graph.list_related_entities(uuid, token, 'develops', direction: 'incoming')
    end

    def configuration=(new_configuration)
      new_configuration = santitize_sizes(new_configuration)
      @configuration = new_configuration
    end

    def configuration
      configuration = @configuration || {}
      defaults = {"sizes" => [{"width" => 600, "height" => 400}]}
      defaults.merge(configuration)
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

    def has_subscription?
      !!(subscription_type && (!end_of_subscription || end_of_subscription.to_i > Time.now.to_i) && !(production? && test_subscription?))
    end

    protected
    def production?
      !['development', 'test'].include?(ENV['RACK_ENV'])
    end

    def test_subscription?
      subscription_type != 'live'
    end

    def santitize_sizes(configuration)
      configuration = configuration.clone

      configuration.delete 'sizes' if sizes_blank?(configuration)
      configuration['sizes'].select! {|size| size_valid?(size)} if configuration['sizes']

      configuration
    end

    def sizes_blank?(configuration)
      configuration.keys.include?('sizes') && (!configuration['sizes'] || !configuration['sizes'].kind_of?(Array) || configuration['sizes'].empty?)
    end

    def size_valid?(size)
      size['width'] && size['height'] && size['width'].kind_of?(Numeric) && size['height'].kind_of?(Numeric) && size['width'] >= 0 && size['height'] >= 0
    end

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
