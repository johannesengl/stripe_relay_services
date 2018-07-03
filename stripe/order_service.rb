module Stripe

  class Order
    def decorate
      StripeOrderDecorator.decorate(self)
    end
  end

  class OrderService

    attr_reader :stripe_order

    def self.list(stripe_ids, merchant)
      return [] unless merchant.try(:stripe_user_id)
      Stripe::Order.list({ids: stripe_ids}, { stripe_account: merchant.stripe_user_id }).data
    end

    def initialize(order)
      @order = order
      @stripe_account_id = @order.merchant.stripe_user_id
      set_stripe_order if @order.stripe_id
    end

    def create(order_params)
      return false if @stripe_order
      set_order_fields(order_params)
      @stripe_order = Stripe::Order.create(order_attributes, account_attributes)
      @order.update(stripe_id: @stripe_order.id, status: :created)
      @stripe_order
    rescue => e
      e.message["Upstream order creation failed: "] = "Couldn't create your order: " if e.message["Upstream order creation failed: "]
      @order.errors.add(:base, e.message)
      false
    end

    def update(status=nil, selected_shipping_method=nil)
      if status
        @stripe_order.status = status
        @order.status = status
      end
      if selected_shipping_method
        @stripe_order.selected_shipping_method = selected_shipping_method
        @order.product_shipping_method_id = selected_shipping_method
      end
      @stripe_order.save
      @order.save
    rescue Stripe::InvalidRequestError => e
      @order.errors.add(:base, e.message)
      false
    end

    def pay(token)
      @stripe_order.pay({ source: token }, account_attributes)
      @order.update(status: @stripe_order.status)
      @stripe_order
    rescue => e
      @order.errors.add(:base, e.message)
      false
    end

    protected

    def account_attributes
      @stripe_account_id.present? ? { stripe_account: @stripe_account_id } : {}
    end

    def set_stripe_order
      @stripe_order ||= Stripe::Order.retrieve(@order.stripe_id, account_attributes)
    rescue Stripe::InvalidRequestError
      return false
    end

    def set_order_fields(order_params)
      @sku = order_params[:sku]
      @quantity = order_params[:quantity]
      @email = order_params[:email]
      @shipping = order_params[:shipping]
    end

    def order_attributes
      {
        currency: 'usd',
        shipping: @shipping,
        email: @email,
        items: order_item_attributes,
        metadata: {
          product_id: @order.product_id
        }
      }
    end

    def order_item_attributes
      sku = Stripe::SkuService.new(@order.product).stripe_object(@sku).decorate
      [
        {
          type: 'sku',
          parent: @sku,
          quantity: @quantity,
          description: "#{@order.product.name} #{sku.attributes_string}"
        }
      ]
    end


  end
end
