require 'bugsnag'

Bugsnag.configure do |config|
  config.api_key = configuration.value("bugsnag.key")
  config.app_type = "soles"
  config.notify_release_stages = %w(development production)
  config.use_ssl = true
  config.project_root = Soles.root
  config.release_stage = Soles.environment
  config.logger = Soles.logger
end