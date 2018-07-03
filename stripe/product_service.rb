module Stripe

  class Product
    def decorate
      StripeProductDecorator.decorate(self)
    end
  end

  class ProductService

    attr_reader :stripe_product

    def initialize(product)
      @product = product
      @stripe_account_id = @product.merchant.stripe_user_id
      set_stripe_product if @product.stripe_id
    end

    def self.list(merchant, ids)
      return [] unless merchant.try(:stripe_user_id)
      Stripe::Product.list({ids: ids}, { stripe_account: merchant.stripe_user_id }).data
    end

    def create(merchant_params)
      return false if @stripe_product
      set_merchant_fields(merchant_params)
      @stripe_product = Stripe::Product.create(product_attributes, account_attributes)
      @product.update(stripe_id: @stripe_product.id)
      create_skus
      refresh_product
      @stripe_product
    rescue Stripe::InvalidRequestError => e
      @product.errors.add(:base, e.message)
      false
    end

    def update(merchant_params)
      return false unless @stripe_product
      set_merchant_fields(merchant_params)
      @stripe_product.name = @name
      @stripe_product.attributes = @attributes
      @stripe_product.images = @images
      @stripe_product.metadata = {id: @id, published: @published}
      @stripe_product.save
      update_skus
      true
    rescue Stripe::InvalidRequestError => e
      @product.errors.add(:base, e.message)
      false
    end

    def destroy
      @stripe_product.skus.each{|sku| sku.delete}
      @stripe_product.delete
    rescue Stripe::InvalidRequestError => e
      @product.errors.add(:base, "The product you attempted to delete cannot be deleted because it is part of an order.")
      false
    end

    protected

    def account_attributes
      @stripe_account_id.present? ? { stripe_account: @stripe_account_id } : {}
    end

    def set_stripe_product
      @stripe_product ||= Stripe::Product.retrieve(@product.stripe_id, account_attributes)
    rescue Stripe::InvalidRequestError
      return false
    end

    def refresh_product
      @stripe_product = @stripe_product.refresh
    end

    def set_merchant_fields(merchant_params)
      @id = merchant_params[:id]
      @published = merchant_params[:published]
      @name = merchant_params[:name]
      @images = merchant_params[:images]
      @attributes = merchant_params[:attributes]
      @skus_params = merchant_params[:skus]
    end

    def product_attributes
      {
        name: @name,
        images: @images,
        shippable: true,
        attributes: @attributes,
        metadata: {id: @id, published: @published}
      }
    end

    def create_skus
      sku_service = SkuService.new(@product)
      @stripe_product.skus = @skus_params.map do |sku_params|
        sku_service.create(sku_params)
      end
    end

    def update_skus
      delete_old_skus_on_product_update
      create_and_update_skus_on_product_update
    end

    def delete_old_skus_on_product_update
      new_sku_ids = @skus_params.map{|sku| sku[:stripe_id]}
      @stripe_product.skus.each do |sku|
        sku_got_deleted = !new_sku_ids.include?(sku.id)
        if sku_got_deleted
          begin
            sku.delete
          rescue Stripe::InvalidRequestError
            sku.active = false
            sku.save
          end
        end
      end
    end

    def create_and_update_skus_on_product_update
      sku_service = SkuService.new(@product)
      existing_sku_ids = @stripe_product.skus.map{|sku| sku.id}
      @stripe_product.skus = @skus_params.map do |sku_params|
        sku_existed = existing_sku_ids.include?(sku_params[:stripe_id])
        if(sku_existed)
          sku_to_be_updated = @stripe_product.skus.find{|sku| sku.id == sku_params[:stripe_id]}
          sku_service.update(sku_to_be_updated, sku_params)
        else
          sku_service.create(sku_params)
        end
      end
    end

  end
end
