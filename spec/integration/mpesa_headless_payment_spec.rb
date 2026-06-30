# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'M-Pesa headless (sourceless) payment', type: :model do
  let(:store) { create(:store) }
  let(:order) { create(:order, store: store).tap { |o| o.update_columns(total: 100, item_total: 100) } }
  let(:payment_method) { create(:mpesa_payment_method, stores: [store]) }

  before do
    stub_request(:get, %r{/oauth/v1/generate}).to_return(
      status: 200, body: { access_token: 'tok', expires_in: '3599' }.to_json
    )
    stub_request(:post, %r{/mpesa/stkpush/v1/processrequest}).to_return(
      status: 200,
      body: { ResponseCode: '0', MerchantRequestID: 'm1', CheckoutRequestID: 'ws_CO_headless',
              CustomerMessage: 'Success' }.to_json
    )
  end

  it 'creates a payment without a source because source is not required' do
    expect(payment_method.source_required?).to be(false)

    payment = order.payments.build(
      payment_method: payment_method, amount: 100, metadata: { 'phone' => '254708374149' }
    )

    expect(payment.save).to be(true)
    expect(payment.source).to be_nil
  end

  context 'when processed through the real Spree payment pipeline' do
    it 'resolves the payment from gateway_options, builds the source from metadata and fires the STK' do
      payment = order.payments.create!(
        payment_method: payment_method, amount: 100, metadata: { 'phone' => '0708374149' }
      )

      payment.authorize!

      expect(payment.reload).to be_pending
      expect(payment.amount).to eq(100)
      expect(payment.source).to be_a(Spree::MpesaSource)
      expect(payment.source.phone).to eq('254708374149')
      expect(payment.source.checkout_request_id).to eq('ws_CO_headless')
    end

    it 'falls back to the order bill address phone when no metadata phone is present' do
      order.update!(bill_address: create(:address, phone: '254712345678'))
      payment = order.payments.create!(payment_method: payment_method, amount: 100)

      payment.authorize!

      expect(payment.reload).to be_pending
      expect(payment.source.phone).to eq('254712345678')
    end

    it 'does not overwrite the payment amount with the cents value Spree passes to authorize' do
      payment = order.payments.create!(
        payment_method: payment_method, amount: 100, metadata: { 'phone' => '254708374149' }
      )

      payment.authorize!

      expect(payment.reload.amount).to eq(100)
    end

    it 'builds a distinct source per payment so a repeat phone cannot hijack a prior payment' do
      first_payment = order.payments.create!(
        payment_method: payment_method, amount: 100, metadata: { 'phone' => '254708374149' }
      )
      first_payment.authorize!

      second_order = create(:order, store: store).tap do |o|
        o.update_columns(total: 100, item_total: 100)
      end
      second_payment = second_order.payments.create!(
        payment_method: payment_method, amount: 100, metadata: { 'phone' => '254708374149' }
      )
      second_payment.authorize!

      expect(first_payment.reload.source).to be_a(Spree::MpesaSource)
      expect(second_payment.reload.source).to be_a(Spree::MpesaSource)
      expect(first_payment.source.id).not_to eq(second_payment.source.id)
    end
  end
end
