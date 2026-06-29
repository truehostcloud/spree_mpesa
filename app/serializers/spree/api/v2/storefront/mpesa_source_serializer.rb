# frozen_string_literal: true

module Spree
  module Api
    module V2
      module Storefront
        class MpesaSourceSerializer < BaseSerializer
          set_type :mpesa_source

          attributes :phone, :status, :mpesa_receipt_number
        end
      end
    end
  end
end
