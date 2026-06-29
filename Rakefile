# frozen_string_literal: true

require 'bundler/setup'

ENV['LIB_NAME'] = 'spree_mpesa'

require 'rspec/core/rake_task'

begin
  require 'spree/testing_support/extension_rake'
rescue LoadError
  nil
end

RSpec::Core::RakeTask.new(:spec)

task default: :spec
