class ApplicationController < Soles::Controller
  describes :app, "Core application commands"

  desc "web", "Start the Sidekiq web server"
  method_option :Host, aliases: "-h", desc: "Host to bind to", default: "127.0.0.1"
  method_option :Port, aliases: "-p", desc: "Port to bind to", default: 8080, type: :numeric
  def web
    require 'sidekiq/web'
    ENV['RACK_ENV'] = Soles.environment
    Sidekiq::Web.set :sessions, false
    app = Rack::Builder.app do
      use Rack::Session::Cookie, :secret => "change_me or use secrets.yml"
      run ::Sidekiq::Web
    end
    full_options = options.to_h.merge(app: app , environment: Soles.environment)
    Rack::Server.start full_options.symbolize_keys
  end
end