unless Kraken.standalone?
  Soles.logger.info "Connecting to Zookeeper..."
  connstr = format("%s%s",
    configuration.value("zookeeper.nodes").join(","),
    configuration.value("zookeeper.chroot", "/"))

  configuration.zookeeper = ZK.new connstr
end