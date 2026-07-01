# frozen_string_literal: true

Spree::Core::Engine.routes.draw do
  # Safaricom Daraja STK Push result callback
  post '/api/v1/mpesa/callback', to: 'mpesa_callbacks#confirm', defaults: { format: 'json' }
end
