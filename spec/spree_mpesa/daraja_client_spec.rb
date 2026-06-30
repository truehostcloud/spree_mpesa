# frozen_string_literal: true

require 'spec_helper'
require 'base64'
require 'json'
require 'httparty'
require 'active_support/core_ext/object/blank'
require_relative '../../lib/spree_mpesa/daraja_client'

RSpec.describe SpreeMpesa::DarajaClient do
  subject(:client) do
    described_class.new(
      consumer_key: 'ckey',
      consumer_secret: 'csecret',
      shortcode: '174379',
      passkey: 'passkey123',
      test_mode: true
    )
  end

  it 'builds basic auth credentials from key and secret' do
    expect(client.send(:credentials)).to eq(Base64.strict_encode64('ckey:csecret'))
  end

  it 'builds the STK password from shortcode, passkey and timestamp' do
    timestamp = '20260622120000'
    expect(client.send(:password, timestamp)).to eq(
      Base64.strict_encode64("174379passkey123#{timestamp}")
    )
  end

  it 'uses the sandbox base url in test mode' do
    expect(client.send(:base_url)).to eq('https://sandbox.safaricom.co.ke')
  end

  it 'uses the production base url when not in test mode' do
    live = described_class.new(
      consumer_key: 'k', consumer_secret: 's', shortcode: '1', passkey: 'p', test_mode: false
    )
    expect(live.send(:base_url)).to eq('https://api.safaricom.co.ke')
  end

  it 'parses a successful STK response into a success hash' do
    response = instance_double(
      HTTParty::Response,
      body: {
        'ResponseCode' => '0',
        'MerchantRequestID' => 'mreq-1',
        'CheckoutRequestID' => 'creq-1',
        'CustomerMessage' => 'Success. Request accepted for processing'
      }.to_json
    )

    result = client.send(:parse_stk_response, response)

    expect(result).to include(
      success: true,
      merchant_request_id: 'mreq-1',
      checkout_request_id: 'creq-1'
    )
  end

  it 'parses a rejected STK response into a failure hash with the error message' do
    response = instance_double(
      HTTParty::Response,
      body: { 'ResponseCode' => '1', 'errorMessage' => 'Invalid Access Token' }.to_json
    )

    result = client.send(:parse_stk_response, response)

    expect(result).to include(success: false, message: 'Invalid Access Token')
  end

  describe '#stk_push' do
    let(:success_body) do
      {
        'ResponseCode' => '0',
        'MerchantRequestID' => 'mreq',
        'CheckoutRequestID' => 'creq',
        'CustomerMessage' => 'Success. Request accepted for processing'
      }.to_json
    end

    it 'posts a correctly shaped STK Push request and returns the checkout id' do
      allow(client).to receive(:access_token).and_return('tok')
      captured = nil
      allow(SpreeMpesa::DarajaClient).to receive(:post) do |url, *rest, **kw|
        opts = kw.any? ? kw : (rest.first || {})
        captured = { url: url, headers: opts[:headers], body: JSON.parse(opts[:body]) }
        instance_double(HTTParty::Response, body: success_body)
      end

      result = client.stk_push(
        phone: '254700000000',
        amount: 1500.0,
        account_reference: 'R123',
        transaction_desc: 'Order R123',
        callback_url: 'https://shop.example/mpesa/callback'
      )

      expect(captured[:url]).to eq('https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest')
      expect(captured[:headers]['Authorization']).to eq('Bearer tok')
      expect(captured[:body]).to include(
        'BusinessShortCode' => '174379',
        'TransactionType' => 'CustomerPayBillOnline',
        'Amount' => 1500,
        'PartyA' => '254700000000',
        'PhoneNumber' => '254700000000',
        'CallBackURL' => 'https://shop.example/mpesa/callback'
      )
      expect(captured[:body]['Password']).to eq(client.send(:password, captured[:body]['Timestamp']))
      expect(result).to include(success: true, checkout_request_id: 'creq')
    end

    it 'returns a failure when Daraja cannot authenticate' do
      allow(client).to receive(:access_token).and_return(nil)

      result = client.stk_push(
        phone: '254700000000', amount: 10, account_reference: 'R1',
        transaction_desc: 'd', callback_url: 'https://x/cb'
      )

      expect(result).to include(success: false)
    end
  end

  describe '#query_stk_status' do
    def stub_query_body(body)
      allow(client).to receive(:access_token).and_return('tok')
      allow(SpreeMpesa::DarajaClient).to receive(:post) do |url, *rest, **kw|
        @captured = { url: url, headers: (kw[:headers] || (rest.first || {})[:headers]) }
        instance_double(HTTParty::Response, body: body)
      end
    end

    it 'posts to the query endpoint with a bearer token' do
      stub_query_body({ 'ResponseCode' => '0', 'ResultCode' => '0', 'ResultDesc' => 'ok' }.to_json)

      client.query_stk_status(checkout_request_id: 'ws_CO_1')

      expect(@captured[:url]).to eq('https://sandbox.safaricom.co.ke/mpesa/stkpushquery/v1/query')
      expect(@captured[:headers]['Authorization']).to eq('Bearer tok')
    end

    it 'reports paid when the transaction succeeded (ResultCode 0)' do
      stub_query_body({ 'ResponseCode' => '0', 'ResultCode' => '0', 'ResultDesc' => 'ok' }.to_json)

      expect(client.query_stk_status(checkout_request_id: 'ws_CO_1')).to include(
        success: true, processed: true, paid: true, result_code: '0'
      )
    end

    it 'reports processed-but-not-paid when still under processing (ResultCode 4999)' do
      stub_query_body({ 'ResponseCode' => '0', 'ResultCode' => '4999',
                        'ResultDesc' => 'The transaction is still under processing' }.to_json)

      expect(client.query_stk_status(checkout_request_id: 'ws_CO_1')).to include(
        success: true, processed: true, paid: false, result_code: '4999'
      )
    end

    it 'reports not processed when Daraja rejects the query (ResponseCode non-zero)' do
      stub_query_body({ 'ResponseCode' => '1', 'errorMessage' => 'Invalid CheckoutRequestID' }.to_json)

      expect(client.query_stk_status(checkout_request_id: 'bogus')).to include(
        success: false, processed: false
      )
    end

    it 'returns a failure when Daraja cannot authenticate' do
      allow(client).to receive(:access_token).and_return(nil)

      expect(client.query_stk_status(checkout_request_id: 'ws_CO_1')).to include(success: false)
    end
  end
end
