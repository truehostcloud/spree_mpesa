# frozen_string_literal: true

module Spree
  module Api
    module V2
      module Platform
        class MpesaSourceSerializer < BaseSerializer
          set_type :mpesa_source

          attributes :phone, :status, :merchant_request_id, :checkout_request_id,
                     :mpesa_receipt_number, :amount, :created_at, :updated_at
        end
      end
    end
  end
end
