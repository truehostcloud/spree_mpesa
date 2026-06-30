# frozen_string_literal: true

Rails.application.config.filter_parameters += %i[
  consumer_key
  consumer_secret
  passkey
  paybill_shortcode
  merchant_request_id
  checkout_request_id
  mpesa_receipt_number
  password
  secret
  token
  api_key
  access_token
  authorization
  phone
  phone_number
]
