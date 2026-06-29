# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spree::PaymentMethod::Mpesa do
  describe '#test_mode?' do
    it 'reflects the preference' do
      expect(build(:mpesa_payment_method, preferred_test_mode: true).test_mode?).to be true
      expect(build(:mpesa_payment_method, preferred_test_mode: false).test_mode?).to be false
    end
  end

  describe '#supports?' do
    subject(:payment_method) { build(:mpesa_payment_method) }

    it 'accepts an MpesaSource' do
      expect(payment_method.supports?(Spree::MpesaSource.new)).to be true
    end

    it 'rejects a foreign source' do
      expect(payment_method.supports?(Object.new)).to be false
    end
  end

  describe '#authorize' do
    let(:store) { create(:store) }
    let(:order) { create(:order, store: store).tap { |o| o.update_columns(total: 100, item_total: 100) } }
    let(:payment_method) { create(:mpesa_payment_method, stores: [store]) }
    let(:source) { create(:mpesa_source, payment_method: payment_method, phone: '254708374149') }
    let(:payment) do
      create(:payment, order: order, payment_method: payment_method, source: source, amount: 10)
    end

    before do
      stub_request(:get, %r{/oauth/v1/generate}).to_return(
        status: 200, body: { access_token: 'tok', expires_in: '3599' }.to_json
      )
    end

    it 'sends an STK push and records the checkout id on success' do
      stub_request(:post, %r{/mpesa/stkpush/v1/processrequest}).to_return(
        status: 200,
        body: { ResponseCode: '0', MerchantRequestID: 'm1', CheckoutRequestID: 'ws_CO_1',
                CustomerMessage: 'Success' }.to_json
      )

      response = payment_method.authorize(10, source, originator: payment)

      expect(response).to be_success
      expect(source.reload.checkout_request_id).to eq('ws_CO_1')
      expect(source.status).to eq('pending')
    end

    it 'returns a failure when Daraja rejects the push' do
      stub_request(:post, %r{/mpesa/stkpush/v1/processrequest}).to_return(
        status: 200, body: { ResponseCode: '1', errorMessage: 'Invalid' }.to_json
      )

      response = payment_method.authorize(10, source, originator: payment)

      expect(response).not_to be_success
    end

    it 'fails fast when the phone is missing' do
      payment
      source.update_column(:phone, '')

      response = payment_method.authorize(10, source, originator: payment)

      expect(response).not_to be_success
    end
  end
end
