require 'soles'
require 'irb'
require 'concurrent'
require 'bundler/setup'
require 'hashie'
require 'active_support/core_ext/hash'
Bundler.require(:default)

module Kraken
  def self.standalone?
    !!ENV["STANDALONE"]
  end

  def self.running?
    @running
  end

  def self.running=(val)
    @running = val
  end

  def self.config(path = nil)
    return Soles.configuration if path.nil?

    fullpath = File.join(Soles.root, "config", "configs", path)
    raise "Not found" unless File.exist? fullpath
    @config_cache ||= {}
    @config_cache[fullpath] ||= begin
      case path
      when /\.json$/
        Hashie::Mash.load fullpath
      when /\.ya?ml$/
        Hashie::Mash.load fullpath
      else
        File.read fullpath
      end
    end
  end

  root = File.expand_path(File.join(__dir__, ".."))
  options = {
    environment_key: "SOLES_ENV",
    config_files: ["config/config.yml", "config/local.yml"]
  }

  Application = Soles::Application.new( root, options ) do |config|
    config.autoload_paths += %w(
      app/controllers
      app/models
      app/lib
      app/workers
      app/subscribers
    )
  end
end

Kraken.running = true