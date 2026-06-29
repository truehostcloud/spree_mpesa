# frozen_string_literal: true

# Allow the M-Pesa source attributes through Spree's permitted source params.
Spree::PermittedAttributes.source_attributes.push(
  :phone,
  :merchant_request_id,
  :checkout_request_id,
  :mpesa_receipt_number,
  :status
).uniq!
