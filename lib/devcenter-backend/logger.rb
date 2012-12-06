require 'logger'

module Devcenter
  module Backend
    class Logger < ::Logger
      alias raw_add add
      def add(*args)
        result = raw_add(*args)
        STDERR.flush
        STDOUT.flush
        result
      end
    end

    def self.log_level
      case ENV['RACK_ENV']
      when 'production'
        Logger::INFO
      when 'test'
        Logger::INFO
      else
        Logger::INFO
      end
    end

    def self.logger
      unless @logger
        @logger = Logger.new(STDERR)
        @logger.level = log_level
      end
      @logger
    end
  end
end
