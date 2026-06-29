# frozen_string_literal: true

module SpreeMpesa
  class Engine < ::Rails::Engine
    require 'spree/core'

    engine_name 'spree_mpesa'
    isolate_namespace Spree

    config.autoload_paths << root.join('lib')

    config.generators do |g|
      g.test_framework :rspec
    end

    config.after_initialize do |app|
      app.config.spree.payment_methods ||= []
      unless app.config.spree.payment_methods.include?(Spree::PaymentMethod::Mpesa)
        app.config.spree.payment_methods << Spree::PaymentMethod::Mpesa
      end
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')).sort.each do |decorator|
        Rails.configuration.cache_classes ? require(decorator) : load(decorator)
      end
    end

    config.to_prepare(&method(:activate).to_proc)
  end
end
