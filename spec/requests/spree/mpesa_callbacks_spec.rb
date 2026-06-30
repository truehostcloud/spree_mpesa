# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'M-Pesa callback', type: :request do
  let(:store) { create(:store) }
  let(:payment_method) { create(:mpesa_payment_method, stores: [store]) }
  let(:order) { create(:order, store: store).tap { |o| o.update_columns(total: 100, item_total: 100) } }
  let(:checkout_request_id) { 'ws_CO_test1' }
  let!(:source) do
    create(:mpesa_source, payment_method: payment_method, amount: 10,
                          status: 'pending', checkout_request_id: checkout_request_id)
  end
  let!(:payment) do
    record = create(:payment, order: order, payment_method: payment_method, source: source, amount: 10)
    record.update_column(:state, 'pending')
    record
  end

  before do
    stub_request(:get, %r{/oauth/v1/generate}).to_return(
      status: 200, body: { access_token: 'tok' }.to_json
    )
  end

  def post_callback(amount: 10, result_code: 0)
    body = { Body: { stkCallback: {
      CheckoutRequestID: checkout_request_id, ResultCode: result_code, ResultDesc: 'ok',
      CallbackMetadata: { Item: [
        { Name: 'Amount', Value: amount },
        { Name: 'MpesaReceiptNumber', Value: 'TX999' }
      ] }
    } } }
    post '/api/v1/mpesa/callback', params: body.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
  end

  def stub_query(result_code:, response_code: '0')
    stub_request(:post, %r{/mpesa/stkpushquery/v1/query}).to_return(
      status: 200,
      body: { ResponseCode: response_code, ResultCode: result_code, ResultDesc: 'x' }.to_json
    )
  end

  it 'completes the payment when Safaricom confirms paid and the amount matches' do
    stub_query(result_code: '0')

    post_callback(amount: 10)

    expect(response).to have_http_status(:ok)
    expect(source.reload.status).to eq('completed')
    expect(source.mpesa_receipt_number).to eq('TX999')
    expect(payment.reload.state).to eq('completed')
  end

  it 'leaves it pending when Safaricom reports still processing' do
    stub_query(result_code: '4999')

    post_callback

    expect(source.reload.status).to eq('pending')
    expect(payment.reload.state).to eq('pending')
  end

  it 'leaves it pending when the callback amount does not match' do
    stub_query(result_code: '0')

    post_callback(amount: 5)

    expect(source.reload.status).to eq('pending')
    expect(payment.reload.state).to eq('pending')
  end

  it 'leaves it pending when Safaricom cannot confirm the transaction' do
    stub_query(result_code: '', response_code: '1')

    post_callback

    expect(source.reload.status).to eq('pending')
    expect(payment.reload.state).to eq('pending')
  end

  it 'ignores a callback for an unknown checkout id' do
    stub_query(result_code: '0')

    body = { Body: { stkCallback: { CheckoutRequestID: 'nope', ResultCode: 0 } } }
    post '/api/v1/mpesa/callback', params: body.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }

    expect(response).to have_http_status(:ok)
    expect(source.reload.status).to eq('pending')
  end
end
