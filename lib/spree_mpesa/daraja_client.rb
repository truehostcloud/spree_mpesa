# frozen_string_literal: true

module SpreeMpesa
  class DarajaClient
    include HTTParty

    SANDBOX_BASE = 'https://sandbox.safaricom.co.ke'
    PRODUCTION_BASE = 'https://api.safaricom.co.ke'

    TRANSPORT_ERRORS = [
      HTTParty::Error,
      Net::OpenTimeout,
      Net::ReadTimeout,
      SocketError,
      OpenSSL::SSL::SSLError,
      Errno::ECONNREFUSED,
      JSON::ParserError
    ].freeze

    def initialize(consumer_key:, consumer_secret:, shortcode:, passkey:,
                   transaction_type: 'CustomerPayBillOnline', test_mode: true)
      @consumer_key = consumer_key
      @consumer_secret = consumer_secret
      @shortcode = shortcode
      @passkey = passkey
      @transaction_type = transaction_type
      @test_mode = test_mode
    end

    def stk_push(phone:, amount:, account_reference:, transaction_desc:, callback_url:)
      token = access_token
      return { success: false, message: 'Unable to authenticate with Daraja' } if token.blank?

      timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      response = self.class.post(
        "#{base_url}/mpesa/stkpush/v1/processrequest",
        headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' },
        body: {
          BusinessShortCode: @shortcode,
          Password: password(timestamp),
          Timestamp: timestamp,
          TransactionType: @transaction_type,
          Amount: amount.to_i,
          PartyA: phone,
          PartyB: @shortcode,
          PhoneNumber: phone,
          CallBackURL: callback_url,
          AccountReference: account_reference.to_s[0, 12],
          TransactionDesc: transaction_desc.to_s[0, 13]
        }.to_json
      )

      parse_stk_response(response)
    rescue *TRANSPORT_ERRORS
      { success: false, message: 'M-Pesa request failed' }
    end

    def query_stk_status(checkout_request_id:)
      token = access_token
      return { success: false, message: 'Unable to authenticate with Daraja' } if token.blank?

      timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      response = self.class.post(
        "#{base_url}/mpesa/stkpushquery/v1/query",
        headers: { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' },
        body: {
          BusinessShortCode: @shortcode,
          Password: password(timestamp),
          Timestamp: timestamp,
          CheckoutRequestID: checkout_request_id
        }.to_json
      )

      parse_query_response(response)
    rescue *TRANSPORT_ERRORS
      { success: false, message: 'M-Pesa request failed' }
    end

    private

    def parse_query_response(response)
      body = JSON.parse(response.body)
      response_code = body['ResponseCode'].to_s
      return { success: false, processed: false, message: body['errorMessage'] || body['ResultDesc'] } unless response_code == '0'

      result_code = body['ResultCode'].to_s
      {
        success: true,
        processed: true,
        paid: result_code == '0',
        result_code: result_code,
        message: body['ResultDesc']
      }
    end

    def parse_stk_response(response)
      body = JSON.parse(response.body)
      if body['ResponseCode'].to_s == '0'
        {
          success: true,
          merchant_request_id: body['MerchantRequestID'],
          checkout_request_id: body['CheckoutRequestID'],
          message: body['CustomerMessage']
        }
      else
        { success: false, message: body['errorMessage'] || body['ResponseDescription'] || 'STK Push failed' }
      end
    end

    def access_token
      response = self.class.get(
        "#{base_url}/oauth/v1/generate?grant_type=client_credentials",
        headers: { 'Authorization' => "Basic #{credentials}" }
      )
      JSON.parse(response.body)['access_token']
    rescue *TRANSPORT_ERRORS
      nil
    end

    def credentials
      Base64.strict_encode64("#{@consumer_key}:#{@consumer_secret}")
    end

    def password(timestamp)
      Base64.strict_encode64("#{@shortcode}#{@passkey}#{timestamp}")
    end

    def base_url
      @test_mode ? SANDBOX_BASE : PRODUCTION_BASE
    end
  end
end
