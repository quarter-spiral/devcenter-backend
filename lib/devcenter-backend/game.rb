module Devcenter::Backend
  class Game
    MASS_ASSIGNABLE_ATTRIBUTES = [:name, :description, :screenshots, :configuration, :developer_configuration, :venues]

    attr_accessor :uuid, :name, :description
    attr_writer :configuration, :screenshots, :developer_configuration, :venues
    attr_reader :original_attributes

    def self.create(params)
      developers = params.delete :developers

      game = new(params.merge(new_game: true))

      ensure_enough_developers!(developers)
      ensure_game_is_valid!(game)

      game.uuid = connection.datastore.create(:public, {'game' => game.to_hash(no_graph: true)})
      game.save
      unless game.adjust_developers(developers)
        game.destroy
        raise Error::BaseError.new("Can't create game with this developer list!")
      end
      connection.graph.add_role(game.uuid, 'game')
      game.mark_as_saved!
      game
    end

    def initialize(params = {})
      params = params.clone
      @new_game = params.delete(:new_game)
      params.delete(:developers)
      raw_update_from_hash(params)

      @original_attributes = to_hash
    end

    def self.find(uuid)
      data = connection.datastore.get(:public, uuid)
      raise Error::NotFoundError.new("Game #{uuid} not found!") unless data
      raise Error::BaseError.new("Entity not a game") unless data['game']

      game = new(data['game'])
      game.uuid = uuid
      game
    end

    def destroy
      connection = self.class.connection
      connection.datastore.set(:public, uuid, {})
      connection.graph.delete_entity(uuid)
    end

    def to_hash(options = {})
      hash = {uuid: uuid, name: name, description: description, configuration: configuration, screenshots: screenshots, developer_configuration: developer_configuration, venues: venues}
      hash[:developers] = developers unless options[:no_graph]
      hash
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
      raise Error.new("Can not mass update: #{unassignable_keys.join(',')}!") unless unassignable_keys.empty?
      raw_update_from_hash(hash)
    end

    def add_developer(developer)
      self.class.connection.graph.add_relationship(developer, uuid, 'develops')
    end

    def remove_developer(developer)
      self.class.connection.graph.remove_relationship(developer, uuid, 'develops')
    end

    def valid?
      raise Error::ValidationError.new("Games must have a name and a description!") unless name.to_s !~ /^\s*$/ && description.to_s !~ /^\s*$/
      raise Error::ValidationError.new("Game configuration invalid!") unless GameType.valid?(self)
      Venue.normalize_game!(self)
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
      self.class.connection.datastore.set(:public, uuid, {'game' => to_hash(no_graph: true)})
    end

    def developers
      return [] unless uuid
      self.class.connection.graph.list_related_entities(uuid, 'develops', direction: 'incoming')
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

    protected
    def raw_update_from_hash(hash)
      hash.each do |key, value|
        value = value.to_hash if value.kind_of?(Hash)
        self.send("#{key}=", value)
      end
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
