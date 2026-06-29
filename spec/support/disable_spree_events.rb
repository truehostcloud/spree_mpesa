# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    if defined?(Spree::Events) && Spree::Events.respond_to?(:disable!)
      Spree::Events.disable!
    end
  end
end
