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

    it 'fails fast when no phone is available on the source, metadata, or order addresses' do
      payment
      source.update_column(:phone, '')
      order.update_columns(bill_address_id: nil, ship_address_id: nil)

      response = payment_method.authorize(10, source, originator: payment)

      expect(response).not_to be_success
    end

    it 'falls back to the order address phone when the passed source phone is blank' do
      stub_request(:post, %r{/mpesa/stkpush/v1/processrequest}).to_return(
        status: 200,
        body: { ResponseCode: '0', MerchantRequestID: 'm1', CheckoutRequestID: 'ws_CO_fallback',
                CustomerMessage: 'Success' }.to_json
      )
      payment
      source.update_column(:phone, '')
      order.update!(bill_address: create(:address, phone: '254712345678'))

      response = payment_method.authorize(10, source, originator: payment)

      expect(response).to be_success
      expect(payment.reload.source.phone).to eq('254712345678')
    end

    it 'fails fast without calling Daraja when the callback URL cannot be resolved' do
      payment
      allow(payment_method).to receive(:callback_url).and_return('')

      response = payment_method.authorize(10, source, originator: payment)

      expect(response).not_to be_success
      expect(response.message).to match(/callback url/i)
    end
  end

  describe '#configured_callback_base' do
    let(:payment_method) { build(:mpesa_payment_method) }

    it 'includes a non-standard port from default_url_options' do
      allow(Rails.application.routes).to receive(:default_url_options).and_return(
        host: 'localhost', port: 3000, protocol: 'https'
      )

      expect(payment_method.send(:configured_callback_base)).to eq('https://localhost:3000')
    end

    it 'omits standard port 443' do
      allow(Rails.application.routes).to receive(:default_url_options).and_return(
        host: 'mpesa.example.com', port: 443, protocol: 'https'
      )

      expect(payment_method.send(:configured_callback_base)).to eq('https://mpesa.example.com')
    end

    it 'returns blank when no host is configured' do
      allow(Rails.application.routes).to receive(:default_url_options).and_return({})

      expect(payment_method.send(:configured_callback_base)).to eq('')
    end
  end

  describe '#callback_url' do
    let(:payment_method) { build(:mpesa_payment_method) }

    it 'builds the api-scoped callback path so the platform proxy reaches Rails' do
      allow(Rails.application.routes).to receive(:default_url_options).and_return(
        host: 'shop.example', protocol: 'https'
      )

      expect(payment_method.send(:callback_url, nil)).to eq('https://shop.example/api/v1/mpesa/callback')
    end
  end

  describe '#default_name' do
    it 'presents the method as Lipa na M-Pesa' do
      expect(Spree::PaymentMethod::Mpesa.new.default_name).to eq('Lipa na M-Pesa')
    end
  end

  describe 'voiding' do
    let(:payment_method) { build(:mpesa_payment_method) }

    it 'never allows voiding because an STK push cannot be cancelled' do
      expect(payment_method.can_void?(Spree::Payment.new)).to be(false)
    end

    it 'returns a failure response when a void is attempted' do
      expect(payment_method.void('ws_CO_1').success?).to be(false)
    end
  end
end
