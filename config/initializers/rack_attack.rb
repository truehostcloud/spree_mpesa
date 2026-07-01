# frozen_string_literal: true

begin
  require 'rack/attack'

  Rails.application.config.after_initialize do
    if defined?(Rack::Attack) && (Rails.env.production? || ENV['ENABLE_RACK_ATTACK'] == 'true')
      Rack::Attack.enabled = true

      Rack::Attack.throttle('mpesa_callback', limit: 60, period: 1.minute) do |req|
        req.ip if req.post? && req.path == '/api/v1/mpesa/callback'
      end

      Rack::Attack.throttled_responder = lambda do |env|
        match_data = env['rack.attack.match_data'] || {}
        headers = {
          'Content-Type' => 'application/json',
          'RateLimit-Limit' => match_data[:limit].to_s,
          'RateLimit-Remaining' => '0'
        }
        body = { status: 'error', message: 'Too many requests. Please try again later.' }.to_json
        [429, headers, [body]]
      end
    elsif defined?(Rack::Attack)
      Rack::Attack.enabled = false
    end
  end
rescue LoadError => e
  Rails.logger.warn("Rack::Attack not loaded: #{e.message}") if defined?(Rails)
end
