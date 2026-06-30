# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'M-Pesa payment source serialization contract', type: :model do
  let(:store) { create(:store) }
  let(:order) { create(:order, store: store).tap { |o| o.update_columns(total: 100, item_total: 100) } }
  let(:payment_method) { create(:mpesa_payment_method, stores: [store]) }
  let(:source) { create(:mpesa_source, payment_method: payment_method, phone: '254708374149') }
  let(:payment) do
    create(:payment, order: order, payment_method: payment_method, source: source, amount: 10)
  end

  it 'answers gateway_payment_profile_id as read by Spree payment serialization' do
    expect(source.gateway_payment_profile_id).to be_nil
  end

  it 'answers gateway_customer_profile_id as read by Spree payment serialization' do
    expect(source.gateway_customer_profile_id).to be_nil
  end

  it 'publishes payment.created for an M-Pesa source without raising' do
    skip 'V3 PaymentSerializer is only loaded by the full Spree stack' unless defined?(Spree::Api::V3::PaymentSerializer)

    payment
    Spree::Events.enable!
    expect { payment.publish_event('payment.created') }.not_to raise_error
  ensure
    Spree::Events.disable!
  end
end
