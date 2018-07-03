require 'rails_helper'

RSpec.describe Stripe::OrderService, type: :service do

  let(:order_params) do
    {
      sku: "sku_ABuiYZg9RYz6Ir",
      stripe_billing_id: "tok_19xdowLiCir3NeQHZowZDnmP",
      shipping: {
        name: "Max Example",
        address: {
          line1: "1181 Clay Str.",
          line2: "Appt. 2",
          city: "San Francisco",
          country: "USA",
          state: "CA",
          postal_code: "94108"
        }
      },
      email: "max.example@gmail.com"
    }
  end

  let(:order) {build(:order)}
  let(:order_service) { Stripe::OrderService.new(order) }

  describe "#create" do

    it 'should return stripe order and set stripe order id', vcr: { cassette_name: 'stripe/order_create' }  do
      stripe_order = order_service.create(order_params)
      expect(stripe_order.id).not_to be(nil)
      expect(order.stripe_id).not_to be(nil)
    end

    it 'should fetch order data from stripe', vcr: { cassette_name: 'stripe/order_fetch' } do
      order_service.create(order_params)
      stripe_order = Stripe::OrderService.new(order).stripe_order
      expect(stripe_order.shipping.name).to eq("Max Example")
    end

  end

  describe "#update" do

    it 'should update order status', vcr: { cassette_name: 'stripe/order_update' } do
      order_service.create(order_params)
      expect(order_service.update("canceled")).to be(true)
      stripe_order = order_service.stripe_order
      expect(stripe_order.status).to eq("canceled")
    end

  end

  describe "#pay" do

    it 'should update order status to paid', vcr: { cassette_name: 'stripe/order_pay' } do
      order_service.create(order_params)
      expect(order_service.pay("tok_19xdowLiCir3NeQHZowZDnmP").status).to eq("paid")
      expect(order.status).to eq("paid")
    end

  end

end
