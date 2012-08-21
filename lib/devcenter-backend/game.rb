module Devcenter::Backend
  class Game
    attr_accessor :uuid

    def self.create(params)
      raise Error.new("You must specify at least one developer!") if params[:developers].empty?

      game = new(params)

      game.uuid = connection.datastore.create(:public, game.to_hash)
      unless game.add_developers(params[:developers])
        game.destroy
        raise Error.new("Can't create game with this developer list!")
      end
      connection.graph.add_role(game.uuid, 'game')
      game
    end

    def initialize(params)
    end

    def destroy
      self.class.connection.datastore.set(:public, uuid, {})
    end

    def to_hash
      {uuid: uuid}
    end

    def add_developers(developers)
      added_developers = []
      developers.each do |developer|
        begin
          self.class.connection.graph.add_relationship(developer, uuid, 'develops')
        rescue Service::Client::ServiceError => e
          if e.error =~ /^Relation:.*is invalid!$/
            added_developers.each {|added_developer| remove_developer(added_developer)}
            return false
          end
          raise e
        end
        added_developers << developer
      end
      true
    end

    def remove_developer(developer)
      self.class.connection.remove_relationship(developer, uuid, 'develops')
    end

    protected
    def self.connection
      @connection ||= Connection.create
    end
  end
end
