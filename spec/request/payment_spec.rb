require_relative '../spec_helper.rb'
require_relative '../request_spec_helper.rb'

require 'uuid'
require 'timecop'

describe Devcenter::Backend::API do
  before do
    AUTH_HELPERS.delete_existing_users!
    AUTH_HELPERS.create_user!

    @connection = ::Devcenter::Backend::Connection.create

    delete_all_games!

    @yourself = user['uuid']
    @game_options = {name: "Test Game", description: "A good game", developers: [@yourself], configuration: {type: "html5", url: "http://example.com/game"}, category: 'Jump n Run'}
    @game = create_game!(@game_options)

    AuthenticationInjector.token = token

    wont_have_subscription(@game)
  end

  after do
    AuthenticationInjector.reset!

    Stripe::Customer.all.each do |customer|
      customer.delete if customer.email == user['email']
    end
  end

  it "can subscribe to a game" do
    subscribe!(fake_payment_token, @game).status.must_equal 201
    must_have_subscription(@game)
  end

  it "cannot subscribe to a game with no token" do
    subscribe!(nil, @game).status.must_equal 402
    wont_have_subscription(@game)
  end

  it "cannot subscribe with an invalid token" do
    subscribe!("some-token", @game).status.must_equal 402
    wont_have_subscription(@game)
  end

  it "will not subscribe you twice" do
    subscribe!(fake_payment_token, @game).status.must_equal 201
    must_have_subscription(@game)
    subscribe!(fake_payment_token, @game).status.must_equal 200
    must_have_subscription(@game)
  end

  it "will not subscribe when the credit card is declined" do
    failing_credit_card_numbers = %w{4000000000000341 4000000000000002 4000000000000069 4000000000000119}

    failing_credit_card_numbers.each do |failing_credit_card_number|
      response = subscribe!(payment_token(failing_credit_card_number), @game)
      response.status.must_equal 402
      JSON.parse(response.body)['error'].wont_be_empty
      wont_have_subscription(@game)
    end
  end

  it "can cancel a subscription and it will be gone at the end of the subscription period" do
    Stripe::Customer.all.each do |customer|
      customer.delete if customer.email == user['email']
    end

    subscribe!(fake_payment_token, @game)
    must_have_subscription(@game)

    unsubscribe!(@game).status.must_equal 200
    # must still have a subscription right now
    must_have_subscription(@game)

    customers = Stripe::Customer.all.select {|customer| customer.email == user['email']}
    customers.size.must_equal 1
    stripe_subscription = customers.first.subscription
    subscriptions_ends_at = stripe_subscription.current_period_end
    subscriptions_ends_at.wont_be_nil

    # must still have a subscription five seconds before the end of the subscription period
    Timecop.freeze(Time.at(subscriptions_ends_at - 5)) do
      must_have_subscription(@game)
    end

    # must not have a subscription anymore after the subscription period ended
    Timecop.freeze(Time.at(subscriptions_ends_at + 1)) do
      wont_have_subscription(@game)
    end
  end

  it "returns 404 when cancelling a non-existent subscription" do
    unsubscribe!(@game).status.must_equal 404
    wont_have_subscription(@game)
  end

  it "can re-subscribe to a game with a cancelled subscription" do
    Stripe::Customer.all.each do |customer|
      customer.delete if customer.email == user['email']
    end

    subscribe!(fake_payment_token, @game)
    unsubscribe!(@game).status.must_equal 200

    customers = Stripe::Customer.all.select {|customer| customer.email == user['email']}
    customers.size.must_equal 1
    stripe_subscription = customers.first.subscription
    subscriptions_ends_at = stripe_subscription.current_period_end
    subscriptions_ends_at.wont_be_nil

    subscribe!(fake_payment_token, @game)

    # must still have a subscription five seconds before the end of the subscription period
    Timecop.freeze(Time.at(subscriptions_ends_at + 100)) do
      must_have_subscription(@game)
    end
  end

  it "cannot change the end of a subscription" do
    subscribe!(fake_payment_token, @game)
    unsubscribe!(@game).status.must_equal 200

    old_end_of_subscription = get_game(@game)['subscription_phasing_out']
    old_end_of_subscription.wont_be_nil

    with_system_level_privileges do
      client.put "/v1/games/#{@game}", {}, JSON.dump(end_of_subscription: nil)
    end
    get_game(@game)['subscription_phasing_out'].must_equal old_end_of_subscription

    with_system_level_privileges do
      client.put "/v1/games/#{@game}", {}, JSON.dump(end_of_subscription: old_end_of_subscription + 1)
    end
    get_game(@game)['subscription_phasing_out'].must_equal old_end_of_subscription
  end

  it "cannot change the subscription type" do
    (!!get_game(@game)['subscription']).must_equal false
    with_system_level_privileges do
      client.put "/v1/games/#{@game}", {}, JSON.dump(subscription_type: 'live')
    end
    (!!get_game(@game)['subscription']).must_equal false
  end
end