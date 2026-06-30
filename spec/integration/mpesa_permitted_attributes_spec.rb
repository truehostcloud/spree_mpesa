# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'M-Pesa permitted source attributes' do
  it 'permits only the customer-supplied phone through Spree source params' do
    attributes = Spree::PermittedAttributes.source_attributes

    expect(attributes).to include(:phone)
  end

  it 'never permits gateway or callback controlled fields from client input' do
    attributes = Spree::PermittedAttributes.source_attributes

    expect(attributes).not_to include(:status)
    expect(attributes).not_to include(:checkout_request_id)
    expect(attributes).not_to include(:merchant_request_id)
    expect(attributes).not_to include(:mpesa_receipt_number)
  end
end
