require 'twitter'

Soles.configuration.twitter = ::Twitter::REST::Client.new do |config|
  config.consumer_key        = Soles.configuration.value("twitter.consumer_key")
  config.consumer_secret     = Soles.configuration.value("twitter.consumer_secret")
end