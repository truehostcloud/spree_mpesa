# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'spree_mpesa'
  s.version     = '1.0.2'
  s.summary     = 'Direct M-Pesa (Safaricom Daraja) payment method for Spree Commerce'
  s.description = 'Spree extension that adds a direct M-Pesa paybill payment method ' \
                  'using the Safaricom Daraja STK Push API, with no third-party aggregator.'
  s.authors     = ['Truehost Cloud']
  s.email       = ['engineering@truehost.cloud']
  s.homepage    = 'https://github.com/truehostcloud/spree_mpesa'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 3.0'

  s.files         = Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  s.require_paths = ['lib']

  s.add_dependency 'httparty', '>= 0.17', '< 1.0'
  s.add_dependency 'spree', '>= 5.0', '< 6.0'

  s.add_development_dependency 'database_cleaner-active_record', '>= 2.0'
  s.add_development_dependency 'factory_bot_rails', '>= 6.2'
  s.add_development_dependency 'rspec', '>= 3.12'
  s.add_development_dependency 'rspec-rails', '>= 6.0'
  s.add_development_dependency 'rubocop', '>= 1.60'
  s.add_development_dependency 'spree_dev_tools'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'webmock', '>= 3.18'
end
