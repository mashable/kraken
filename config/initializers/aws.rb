require 'aws-sdk'

Aws.config.update(
  region: Kraken.config.value("aws.credentials.region"),
  credentials: Aws::Credentials.new(Kraken.config.value("aws.credentials.access_key_id"), Kraken.config.value("aws.credentials.secret_access_key"))
)