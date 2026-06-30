# frozen_string_literal: true

class CreateSpreeMpesaSources < ActiveRecord::Migration[7.1]
  def change
    create_table :spree_mpesa_sources do |t|
      t.references :payment_method, index: true
      t.references :user, index: true
      t.string :phone
      t.string :merchant_request_id
      t.string :checkout_request_id
      t.string :mpesa_receipt_number
      t.string :status, default: 'pending'
      t.integer :result_code
      t.string :result_desc
      t.decimal :amount, precision: 10, scale: 2
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :spree_mpesa_sources, :checkout_request_id, unique: true
    add_index :spree_mpesa_sources, :merchant_request_id, unique: true
    add_index :spree_mpesa_sources, :deleted_at
  end
end
