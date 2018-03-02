require 'sidekiq'
require 'sidekiq/web'
require 'rack'

class Sidekiq::WebWorker
  def initialize(root = ".")
    @root = root
  end

  def run(options = {}, &block)
    configuration = YAML.load File.read(File.join(@root, "config/config.yml"))
    env = ENV["RACK_ENV"] || "development"

    Thread.abort_on_exception = true
    Sidekiq.configure_client do |config|
      p [:env, env, configuration[env]["redis"]["url"]]
      config.redis = { url: configuration[env]["redis"]["url"], size: 1 }
    end
  
    Rack::Server.start options.merge(app: ::Sidekiq::Web, environment: "none")
  end
end