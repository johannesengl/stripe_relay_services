class TaxjarService

  require 'taxjar'

  def initialize(order, taxable_amount_in_cent, customer_address)
    @client = Taxjar::Client.new(api_key: ENV['TAXJAR_API_KEY'])
    @order = order
    @taxable_amount_in_cent = taxable_amount_in_cent
    @customer_address = customer_address
  end

  def calc_tax
    @order.tax = (@client.tax_for_order(order_attributes).amount_to_collect * 100).round
    @order
  rescue Taxjar::Error => e
    m = e.message
    m["to_zip"] = "Zip"
    m["to_state"] = "state"
    @order.errors.add(:base, m)
    @order
  end

  protected

  def order_attributes
    merchant_address = @order.merchant.merchant_address
    {
      from_street: merchant_address.street,
      from_city: merchant_address.city,
      from_state: merchant_address.state,
      from_zip: merchant_address.postal_code,
      from_country: merchant_address.country,
      to_street: @customer_address[:line1],
      to_city: @customer_address[:city],
      to_state: @customer_address[:state],
      to_zip: @customer_address[:postal_code],
      to_country: @customer_address[:country],
      amount: @taxable_amount_in_cent.to_f / 100,
      shipping: 0,
    }
  end

end
