module Devcenter::Backend
  class Game
    attr_accessor :uuid, :name, :description
    attr_writer :configuration, :screenshots, :developer_configuration
    attr_reader :original_attributes

    def self.create(params)
      game = new(params.merge(new_game: true))

      ensure_enough_developers!(params)
      ensure_game_is_valid!(game)

      game.uuid = connection.datastore.create(:public, {'game' => game.to_hash(no_graph: true)})
      game.save
      unless game.adjust_developers(params[:developers])
        game.destroy
        raise Error.new("Can't create game with this developer list!")
      end
      connection.graph.add_role(game.uuid, 'game')
      game.mark_as_saved!
      game
    end

    def initialize(params = {})
      @name = params['name']
      @description = params['description']
      @configuration = params['configuration'].to_hash if params['configuration']
      @screenshots = params['screenshots']
      @developer_configuration = params['developer_configuration'].to_hash if params['developer_configuration']
      @new_game = params[:new_game]

      @original_attributes = to_hash
    end

    def destroy
      connection = self.class.connection
      connection.datastore.set(:public, uuid, {})
      connection.graph.delete_entity(uuid)
    end

    def to_hash(options = {})
      hash = {uuid: uuid, name: name, description: description, configuration: configuration, screenshots: screenshots, developer_configuration: developer_configuration}
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

    def add_developer(developer)
      self.class.connection.graph.add_relationship(developer, uuid, 'develops')
    end

    def remove_developer(developer)
      self.class.connection.graph.remove_relationship(developer, uuid, 'develops')
    end

    def valid?
      raise ValidationError.new("Games must have a name and a description!") unless name.to_s !~ /^\s*$/ && description.to_s !~ /^\s*$/
      raise ValidationError.new("Game configuration invalid!") unless GameType.valid?(self)
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

    protected
    def self.connection
      @connection ||= Connection.create
    end

    def self.ensure_enough_developers!(params)
      raise Error.new("Games must have at least one developer!") if !params[:developers] || params[:developers].empty?
    end

    def self.ensure_game_is_valid!(game)
      # game validation raises errors from within itself
      game.valid?
    end
  end
end
