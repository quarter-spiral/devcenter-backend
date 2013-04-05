require 'stripe'

Stripe.api_key = ENV['QS_STRIPE_SECRET_KEY']

module Devcenter::Backend
  class PaymentProcessor
    class Exception < StandardError
    end

    DEFAULT_PLAN = "friendbarus-default"

    def start_subscription(user, game, stripe_token)
      customer = create_customer(user, game, stripe_token)
      subscription = customer.update_subscription(plan: DEFAULT_PLAN)

      game.end_of_subscription = nil
      game.subscription_type = subscription.plan.livemode ? 'live' : 'test'
      game.subscription_customer_id = customer.id
      game.save
    rescue Stripe::StripeError => e
      raise Exception.new(e)
    end

    def cancel_subscription(game)
      customer = retrieve_customer(game.subscription_customer_id)
      raise Exception.new("Customer not found") unless customer

      subscription = customer.cancel_subscription(at_period_end: true)
      raise Exception.new("Could not cancel the subscription!") unless subscription['cancel_at_period_end']

      game.end_of_subscription = subscription['current_period_end']
      game.save

    rescue Stripe::StripeError => e
      raise Exception.new(e)
    end

    protected
    def retrieve_customer(customer_id)
      Stripe::Customer.retrieve(customer_id)
    rescue Stripe::StripeError => e
      return nil if e.http_status == 404
      raise Exception.new(e)
    end

    def create_customer(user, game, stripe_token)
      Stripe::Customer.create(
        description: "User UUID: #{user['uuid']} | Game UUID: #{game.uuid}",
        card: stripe_token,
        email: user['email']
      )
    end
  end
end