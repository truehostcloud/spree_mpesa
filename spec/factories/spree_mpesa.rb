# frozen_string_literal: true

require 'securerandom'

FactoryBot.define do
  factory :mpesa_payment_method, class: 'Spree::PaymentMethod::Mpesa' do
    name { 'M-Pesa' }
    active { true }
    preferred_test_mode { true }
    preferred_paybill_shortcode { '174379' }
    preferred_consumer_key { 'ckey' }
    preferred_consumer_secret { 'csecret' }
    preferred_passkey { 'passkey123' }

    transient do
      stores { [] }
    end

    after(:create) do |payment_method, evaluator|
      payment_method.stores = evaluator.stores if evaluator.stores.present?
    end
  end

  factory :mpesa_source, class: 'Spree::MpesaSource' do
    association :payment_method, factory: :mpesa_payment_method
    phone { '254708374149' }
    status { 'pending' }
    amount { 10 }
    checkout_request_id { "ws_CO_#{SecureRandom.hex(6)}" }
  end
end
