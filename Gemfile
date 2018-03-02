source 'https://rubygems.org'

gem 'soles', github: "cheald/soles"
gem 'sidekiq'
gem 'hiredis'
gem 'redis', '>= 3.2.0', require: ['redis', 'redis/connection/hiredis']
gem 'connection_pool'
gem 'ruby-kafka', github: 'zendesk/ruby-kafka', ref: 'v0.5.0.beta1'
gem 'twitter', '~> 6.1'
gem 'koala'
gem 'bugsnag', '~> 5.5'
gem 'zk'
gem 'rufus-scheduler', '~> 3.0'
gem 'awesome_print'
gem 'faraday'
gem 'faraday_middleware'
gem 'avro_turf'
gem 'avro-builder'
gem 'avromatic'
gem 'hashie'
gem 'rack'
gem 'addressable'
gem 'aws-sdk'
gem 'oauth2'
gem 'virtus'
gem 'nokogiri'
gem "redis-bloomfilter", github: "cheald/redis-bloomfilter"

group :test do
  gem 'rspec'
  gem 'webmock'
  gem 'vcr', '~> 3.0'
  gem 'timecop'
  gem 'simplecov', require: false
end

group :development do
  gem 'pry'
end

# Deployment
group :development do
  gem 'capistrano'
  gem 'capistrano-bundler', require: false
  gem 'cap-ec2', github: "cheald/cap-ec2", branch: "raw_filters", require: false
  gem 'capistrano-rvm', github: "cheald/rvm", require: false
  gem "airbrussh", require: false

  # Needed to support newer key types
  gem 'rbnacl-libsodium'
  gem 'rbnacl', '~> 3.0'
  gem 'bcrypt_pbkdf', platform: :ruby
end
