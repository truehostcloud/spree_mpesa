# frozen_string_literal: true

module Spree
  class PaymentMethod::Mpesa < ::Spree::PaymentMethod
    PAYBILL_TRANSACTION_TYPE = 'CustomerPayBillOnline'

    preference :paybill_shortcode, :string
    preference :consumer_key, :string
    preference :consumer_secret, :string
    preference :passkey, :string
    preference :test_mode, :boolean, default: true

    def partial_name
      'mpesa'
    end

    def configuration_guide_partial_name
      'mpesa'
    end

    def default_name
      'Lipa na M-Pesa'
    end

    def payment_source_class
      Spree::MpesaSource
    end

    def source_required?
      false
    end

    def payment_profiles_supported?
      false
    end

    def auto_capture?
      false
    end

    def supports?(source)
      source.nil? || source.is_a?(Spree::MpesaSource)
    end

    def reusable_sources(_order)
      []
    end

    def can_capture?(payment)
      payment.pending? || payment.checkout?
    end

    def can_void?(_payment)
      false
    end

    def test_mode?
      ActiveModel::Type::Boolean.new.cast(preferred_test_mode)
    end

    def authorize(amount, source, options = {})
      payment = resolve_payment(source, options)
      return failure_response('Payment is missing') unless payment.is_a?(Spree::Payment)

      mpesa_source = ensure_source(source, payment)
      return failure_response('Phone number is required for M-Pesa payments') if mpesa_source&.phone.blank?

      payment.source = mpesa_source
      payment.payment_method ||= self
      return failure_response(payment.errors.full_messages.to_sentence) unless payment.save

      initiate_stk_push(payment: payment, source: mpesa_source, amount: payment.amount)
    rescue ActiveRecord::ActiveRecordError
      failure_response('Authorization could not be completed')
    end
  
    def purchase(amount, source, options = {})
      authorize(amount, source, options)
    end

    def capture(_amount, response_code, _options = {})
      source = Spree::MpesaSource.find_by(checkout_request_id: response_code)
      return success_response('Payment captured', authorization: response_code) if source&.completed?

      failure_response('Awaiting M-Pesa confirmation')
    end

    def void(_response_code, _options = {})
      failure_response('M-Pesa payments cannot be voided; reverse the transaction in M-Pesa and reconcile manually')
    end

    def daraja_client
      SpreeMpesa::DarajaClient.new(
        consumer_key: preferred_consumer_key,
        consumer_secret: preferred_consumer_secret,
        shortcode: preferred_paybill_shortcode,
        passkey: preferred_passkey,
        transaction_type: PAYBILL_TRANSACTION_TYPE,
        test_mode: test_mode?
      )
    end

    def success_response(message = 'Success', authorization: nil)
      Spree::PaymentResponse.new(true, message, {}, authorization: authorization, test: test_mode?)
    end

    def failure_response(message = 'Failed')
      Spree::PaymentResponse.new(false, message, {}, test: test_mode?)
    end

    private

    def resolve_payment(_source, options)
      return options[:originator] if options[:originator].is_a?(Spree::Payment)

      Spree::Payment.find_by(number: options[:payment_id])
    end

    def initiate_stk_push(payment:, source:, amount:)
      return failure_response('M-Pesa configuration is incomplete') unless configured?

      callback = callback_url(payment.order)
      return failure_response('Callback URL is not configured') if callback.blank?

      result = daraja_client.stk_push(
        phone: source.phone,
        amount: amount.to_f,
        account_reference: payment.order.number,
        transaction_desc: "Order #{payment.order.number}",
        callback_url: callback
      )

      return failure_response(result[:message] || 'Failed to initiate M-Pesa payment') unless result[:success]

      source.update!(
        merchant_request_id: result[:merchant_request_id],
        checkout_request_id: result[:checkout_request_id],
        amount: amount,
        status: Spree::MpesaSource::PENDING
      )

      Spree::PaymentResponse.new(
        true,
        'M-Pesa request sent. Enter your PIN on your phone to complete the payment.',
        { checkout_request_id: result[:checkout_request_id] },
        authorization: result[:checkout_request_id],
        test: test_mode?
      )
    end

    def configured?
      preferred_paybill_shortcode.present? && preferred_consumer_key.present? &&
        preferred_consumer_secret.present? && preferred_passkey.present?
    end

    def callback_url(order)
      base = order&.store&.storefront_url.presence || configured_callback_base
      return '' if base.blank?

      "#{base.chomp('/')}/api/v1/mpesa/callback"
    end

    def configured_callback_base
      options = Rails.application.routes.default_url_options
      host = options[:host]
      return '' if host.blank?

      protocol = options[:protocol].presence || 'https'
      port = options[:port].presence
      host_with_port = port && ![80, 443].include?(port.to_i) ? "#{host}:#{port}" : host
      "#{protocol}://#{host_with_port}"
    end

    def ensure_source(source, payment)
      mpesa_source = source.presence || payment.source
      return mpesa_source if mpesa_source.is_a?(Spree::MpesaSource) && mpesa_source.phone.present?

      phone = payment.metadata&.dig('phone') ||
              payment.order&.bill_address&.phone ||
              payment.order&.ship_address&.phone
      return if phone.blank?

      Spree::MpesaSource.create!(payment_method: self, phone: phone)
    end
  end
end
