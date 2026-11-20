# frozen_string_literal: true

source 'https://rubygems.org'

# Runtime dependencies are declared in epzip.gemspec.
gemspec

# CI sets RUBYZIP_VERSION to test against each supported rubyzip series.
gem 'rubyzip', ENV['RUBYZIP_VERSION'] if ENV['RUBYZIP_VERSION']

group :development, :test do
  gem 'rake'
  gem 'test-unit'
end
