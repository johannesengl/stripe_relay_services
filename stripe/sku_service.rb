module Stripe

  class SKU
    def decorate
      StripeSkuDecorator.decorate(self)
    end
  end

  class SkuService

    def initialize(product)
      @product = product
      @stripe_account_id = @product.merchant.stripe_user_id
    end

    def create(sku_params)
      set_sku_fields(sku_params)
      Stripe::SKU.create(sku_attributes, account_attributes)
    end

    def update(sku, sku_params)
      set_sku_fields(sku_params)
      sku.price = @price
      sku.inventory.quantity = @quantity
      sku.save
    end

    def stripe_object(sku_id)
      Stripe::SKU.retrieve(sku_id, account_attributes)
    end

    protected

    def account_attributes
      @stripe_account_id.present? ? { stripe_account: @stripe_account_id } : {}
    end

    def set_sku_fields(sku_params)
      @price = (sku_params[:price].to_f * 100).round
      @quantity = sku_params[:quantity].to_i
      @attributes = sku_params[:attributes]
    end

    def sku_attributes
      {
        product: @product.stripe_id,
        price: @price,
        currency: 'usd',
        attributes: @attributes,
        inventory: {
          'type' => 'finite',
          'quantity' => @quantity
        }
      }
    end
  end
end
