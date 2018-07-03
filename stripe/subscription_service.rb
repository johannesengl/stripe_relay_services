module Stripe

  class SubscriptionService

    attr_reader :stripe_subscription

    def initialize(subscription)
      @subscription = subscription
      set_stripe_subscription if @subscription.stripe_id
    end

    def create
      cancel if @stripe_subscription
      customer = Stripe::Customer.create(customer_params)
      @subscription.stripe_customer_id = customer.id
      @subscription.stripe_id = customer.subscriptions.first.id
    rescue Stripe::InvalidRequestError => e
      @subscription.errors.add(:base, e.message)
    end

    def cancel
      @stripe_subscription.delete(at_period_end: true) if @stripe_subscription
    rescue Stripe::InvalidRequestError => e
      @subscription.errors.add(:base, e.message)
    end

    def reactivate
      @stripe_subscription.save if @stripe_subscription
    rescue Stripe::InvalidRequestError => e
      @subscription.errors.add(:base, e.message)
    end

    protected

    def set_stripe_subscription
      @stripe_subscription ||= Stripe::Subscription.all(status: 'all', customer: @subscription.stripe_customer_id).first
    rescue Stripe::InvalidRequestError
      return false
    end

    def customer_params
      customer_params = {
        source: @subscription.stripe_billing_id,
        plan: (@subscription.plan == "pro" || @subscription.plan == "company") ? @subscription.plan : "pro",
        email: @subscription.user.email
      }
      customer_params[:coupon] = @subscription.promo_code if @subscription.promo_code.present?
      customer_params
    end

  end
end
