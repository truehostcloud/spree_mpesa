# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spree::MpesaSource do
  describe 'phone normalization' do
    it 'converts a local 0-prefixed number to 2547 format' do
      source = build(:mpesa_source, payment_method: nil, phone: '0712345678')
      source.valid?
      expect(source.phone).to eq('254712345678')
    end

    it 'prefixes a bare 9-digit number with 254' do
      source = build(:mpesa_source, payment_method: nil, phone: '712345678')
      source.valid?
      expect(source.phone).to eq('254712345678')
    end

    it 'strips spaces and the plus from a +254 number' do
      source = build(:mpesa_source, payment_method: nil, phone: '+254 712 345 678')
      source.valid?
      expect(source.phone).to eq('254712345678')
    end

    it 'is invalid without a phone' do
      source = build(:mpesa_source, payment_method: nil, phone: nil)
      expect(source).not_to be_valid
    end
  end

  describe '#completed?' do
    it 'is true only when the status is completed' do
      expect(build(:mpesa_source, payment_method: nil, status: 'completed')).to be_completed
      expect(build(:mpesa_source, payment_method: nil, status: 'pending')).not_to be_completed
    end
  end

  describe 'voiding' do
    it 'advertises only the capture action' do
      expect(build(:mpesa_source, payment_method: nil).actions).to eq(%w[capture])
    end

    it 'never allows voiding because an STK push cannot be cancelled' do
      expect(build(:mpesa_source, payment_method: nil).can_void?(Spree::Payment.new)).to be(false)
    end
  end
end
