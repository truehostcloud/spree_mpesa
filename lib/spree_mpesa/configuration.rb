# frozen_string_literal: true

module SpreeMpesa
  class Configuration
    class << self
      def preferences
        @preferences ||= default_preferences
      end

      def default_preferences
        {
          paybill_shortcode: nil,
          consumer_key: nil,
          consumer_secret: nil,
          passkey: nil,
          transaction_type: 'CustomerPayBillOnline',
          test_mode: true
        }.freeze
      end

      def [](key)
        preferences[key.to_sym]
      end
    end
  end
end
