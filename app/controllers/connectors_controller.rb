class Connectors < Soles::Controller
  describes :connectors, "Kafka connectors commands"

  desc "list", "List Kafka connectors"
  def list
    ap conn.get("/connectors/").body
  end

  desc "status", "List the status of Kafka connectors"
  def status
    conn.get("/connectors/").body.each do |connector|
      puts "-" * 40
      puts "Config:"
      puts JSON.pretty_generate(conn.get("/connectors/#{connector}/").body)
      puts "Status:"
      puts JSON.pretty_generate(conn.get("/connectors/#{connector}/status/").body)
    end
  end

  desc "restart CONNECTOR", "restart a Kafka connector"
  def restart(connector)
    resp = conn.post("/connectors/#{connector}/restart") do |req|
      req.headers['Content-Type'] = "application/json"
    end
    if (200..209).cover? resp.status
      puts "OK"
    else
      puts "Error restarting #{connector}: #{resp.status}"
    end
    puts resp.body
  end

  desc "pause CONNECTOR", "Pause a Kafka connector"
  def pause(connector)
    resp = conn.put("/connectors/#{connector}/pause")
    if resp.status == 200
      puts "OK"
    else
      puts "Error pausing #{connector}: #{resp.status}"
    end
  end

  desc "resume CONNECTOR", "Resume a Kafka connector"
  def resume(connector)
    resp = conn.put("/connectors/#{connector}/resume")
    if resp.status == 200
      puts "OK"
    else
      puts "Error resuming #{connector}: #{resp.status}"
    end
  end

  desc "setup", "Sync the connector configs to the kafka-connect cluster"
  def setup
    Dir[File.join(Soles.root, "app", "workers", "**", "*.rb")].each do |f|
      require f
    end
    Kraken.config.topic_registry.generate_registries!
  end

  desc "cleanup", ""
  def cleanup
    Dir[File.join(Soles.root, "app", "workers", "**", "*.rb")].each do |f|
      require f
    end
    Kraken.config.topic_registry.cleanup_registries!
  end

  private

  def conn
    @conn ||= begin
      servers = Array(Kraken.config.value("kafka.connect"))
      Faraday.new(servers.sample) do |faraday|
        faraday.response :json, content_type: /\bjson$/
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end