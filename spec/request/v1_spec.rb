require_relative '../spec_helper.rb'

require 'json'
require 'rack/client'

include Devcenter::Backend

def client
  @client ||= Rack::Client.new {run API}
end

describe Devcenter::Backend::API do
  before do
  end
end
