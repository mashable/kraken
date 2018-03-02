require 'sidekiq'
require 'yaml'

configuration = YAML.load File.read("config/config.yml")

p ENV
Sidekiq.configure_client do |config|
  config.redis = { url: configuration[ENV["RACK_ENV"]]["redis"]["url"], size: 1 }
end

require 'sidekiq/web'
map '/' do
  # use Rack::Auth::Basic, "Protected Area" do |username, password|
  #   # Protect against timing attacks:
  #   # - See https://codahale.com/a-lesson-in-timing-attacks/
  #   # - See https://thisdata.com/blog/timing-attacks-against-string-comparison/
  #   # - Use & (do not use &&) so that it doesn't short circuit.
  #   # - Use digests to stop length information leaking
  #   Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USERNAME"])) &
  #     Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"]))
  # end

  run Sidekiq::Web
end