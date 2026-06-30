# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('dummy/config/environment.rb', __dir__)

require 'spree_dev_tools/rspec/spec_helper'
require 'webmock/rspec'

Dir[File.join(__dir__, 'support/**/*.rb')].sort.each { |f| require f }

WebMock.disable_net_connect!(allow_localhost: true)
