# frozen_string_literal: true

module Spree
  class MpesaSource < Spree::Base
    PENDING = 'pending'
    COMPLETED = 'completed'
    FAILED = 'failed'

    belongs_to :payment_method, class_name: 'Spree::PaymentMethod::Mpesa', optional: true
    belongs_to :user, class_name: Spree.user_class.to_s, optional: true
    has_many :payments, as: :source, class_name: 'Spree::Payment'

    before_validation :normalize_phone

    validates :phone, presence: true

    def actions
      %w[capture void]
    end

    def can_capture?(payment)
      payment.pending? || payment.checkout?
    end

    def can_void?(payment)
      !payment.failed? && !payment.void?
    end

    def completed?
      status == COMPLETED
    end

    def name
      phone
    end

    def display_number
      phone
    end

    def gateway_customer_profile_id
      nil
    end

    def gateway_payment_profile_id
      nil
    end

    private

    def normalize_phone
      digits = phone.to_s.gsub(/\D/, '')
      return if digits.blank?

      self.phone =
        if digits.length == 10 && digits.start_with?('0')
          "254#{digits[1..]}"
        elsif digits.length == 9
          "254#{digits}"
        else
          digits
        end
    end
  end
end
