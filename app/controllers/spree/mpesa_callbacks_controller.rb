# frozen_string_literal: true

module Spree
  class MpesaCallbacksController < ActionController::Base
    STILL_PROCESSING_RESULT_CODE = '4999'

    layout false
    skip_before_action :verify_authenticity_token, only: [:confirm], raise: false

    def confirm
      callback = params.dig(:Body, :stkCallback) || {}
      source = Spree::MpesaSource.find_by(checkout_request_id: callback[:CheckoutRequestID])
      return head(:ok) if source.blank? || source.status != Spree::MpesaSource::PENDING

      case verify_with_safaricom(source)
      when :paid
        settle_paid(source, callback) if amount_matches?(source, callback)
      when :failed
        source.update(
          status: Spree::MpesaSource::FAILED,
          result_desc: callback[:ResultDesc]
        )
      end

      head :ok
    end

    private

    def verify_with_safaricom(source)
      method = source.payment_method
      return :unconfirmed unless method.is_a?(Spree::PaymentMethod::Mpesa)

      result = method.daraja_client.query_stk_status(checkout_request_id: source.checkout_request_id)
      return :unconfirmed unless result[:success] && result[:processed]
      return :paid if result[:paid]
      return :unconfirmed if result[:result_code].to_s == STILL_PROCESSING_RESULT_CODE

      :failed
    end

    def settle_paid(source, callback)
      source.update(
        result_code: 0,
        result_desc: callback[:ResultDesc],
        mpesa_receipt_number: receipt_number(callback),
        status: Spree::MpesaSource::COMPLETED
      )
      complete_payment(source)
    end

    def amount_matches?(source, callback)
      return true if source.amount.blank?

      paid = amount_paid(callback)
      return false if paid.nil?

      paid >= source.amount
    end

    def amount_paid(callback)
      items = callback.dig(:CallbackMetadata, :Item) || []
      entry = items.find { |item| item[:Name] == 'Amount' }
      entry && entry[:Value].to_d
    end

    def complete_payment(source)
      payment = source.payments.last
      return if payment.blank? || payment.completed?

      payment.complete!
    rescue StateMachines::InvalidTransition
      nil
    end

    def receipt_number(callback)
      items = callback.dig(:CallbackMetadata, :Item) || []
      entry = items.find { |item| item[:Name] == 'MpesaReceiptNumber' }
      entry && entry[:Value]
    end
  end
end
