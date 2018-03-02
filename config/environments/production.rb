# This is the environment file for the production environment. You can start your Soles application with
# `soles run production` or `SOLES_ENV=production soles run`.

Soles.logger = Logger.new(File.join(Soles.root, "log", "kraken.production.log"), 5, 128.megabytes)