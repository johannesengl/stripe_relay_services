require 'rails_helper'

RSpec.describe Stripe::ProductService, type: :service do

  let(:product_params) do
    {
      name: "Test Product",
      attributes: ['color'],
      skus: [
        {price: 100, quantity: 10, attributes: {'color' => "blue"}},
        {price: 200, quantity: 10, attributes: {'color' => "green"}}
      ]
    }
  end

  let(:purchasable_product) {create(:purchasable_product)}
  let(:product_service) { Stripe::ProductService.new(purchasable_product) }

  describe "#create" do

    context 'when valid' do

      it 'should return stripe product with id, name and skus', vcr: { cassette_name: 'stripe/product_create' }  do
        stripe_product = product_service.create(product_params)
        expect(stripe_product.id).not_to be(nil)
        expect(stripe_product.name).to eq("Test Product")
        expect(stripe_product.skus.count).to eq(2)
      end

      it 'should fetch commerce product data from stripe', vcr: { cassette_name: 'stripe/product_fetch' } do
        product_service.create(product_params)
        expect(purchasable_product.stripe_id).not_to be(nil)
        stripe_product = Stripe::ProductService.new(purchasable_product).stripe_product
        expect(stripe_product.skus.first.price).to eq(10000)
      end

    end

  end

  describe "#update" do

    before(:each) do
      product_service.create(product_params)
    end

    it 'should update price and quantity on stripe', vcr: { cassette_name: 'stripe/product_update_inventory_and_price' } do
      skus = product_service.stripe_product.skus.data
      product_params[:skus] = [
        {id: skus.first.id, price: 200, quantity: 20, attributes: skus.first.attributes.to_hash},
        {id: skus.last.id, price: 300, quantity: 30, attributes: skus.last.attributes.to_hash}
      ]
      expect(product_service.update(product_params)).to be(true)

      stripe_product = product_service.stripe_product.decorate
      expect(stripe_product.skus.first.exact_price).to eq(200)
      expect(stripe_product.skus.first.inventory.quantity).to eq(20)
      expect(stripe_product.skus.last.exact_price).to eq(300)
      expect(stripe_product.skus.last.inventory.quantity).to eq(30)
      expect(stripe_product.skus.count).to eq(2)
    end

    it 'shoud create new skus', vcr: { cassette_name: 'stripe/product_update_create_sku' } do
      skus = product_service.stripe_product.skus.data
      product_params[:skus] = [
        {id: skus.first.id, price: 200, quantity: 20, attributes: skus.first.attributes.to_hash},
        {id: skus.last.id, price: 300, quantity: 30, attributes: skus.last.attributes.to_hash},
        {price: 50, quantity: 10, attributes: {'color' => "gold"}}
      ]
      expect(product_service.update(product_params)).to be(true)
      stripe_product = product_service.stripe_product
      expect(stripe_product.skus.count).to eq(3)
    end

    it 'shoud deactivate skus if got deleted', vcr: { cassette_name: 'stripe/product_update_remove_sku' } do
      skus = product_service.stripe_product.skus.data
      product_params[:skus] = [
        {id: skus.first.id, price: 200, quantity: 20, attributes: skus.first.attributes.to_hash}
      ]
      expect(product_service.update(product_params)).to be(true)
      stripe_product = product_service.stripe_product
      expect(stripe_product.skus.count).to eq(1)
    end

  end

end
