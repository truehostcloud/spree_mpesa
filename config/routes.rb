# frozen_string_literal: true

Spree::Core::Engine.routes.draw do
  # Safaricom Daraja STK Push result callback
  post '/mpesa/callback', to: 'mpesa_callbacks#confirm', defaults: { format: 'json' }
end
