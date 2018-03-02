require 'active_support/core_ext/class/subclasses'

class PollingZKScheduler < ZookeptScheduler
  def load_workers!
    # Load all the workers
    workers = Dir.glob(File.join(Soles.root, "app", "workers", "**", "*.rb"))
    Soles.logger.info "Workers: #{workers.inspect}"
    workers.each do |f|
      begin
        require f
      rescue e
        Sole.logger.error "Error loading #{f}: #{e.message}"
        Bugsnag.notify e
      end
    end
  end

  def setup_jobs!
    return if @setup_jobs
    load_workers!
    # Set up job production
    abort = Thread.abort_on_exception
    Thread.abort_on_exception = true
    Soles.configuration.scheduler.tap do |s|
      BaseWorker.descendants.each do |klass|
        options = klass.production_options
        if options.present?
          key = options[:every] || options[:at] || options[:cron]
          if key.present? && options[:block].respond_to?(:call)
            period = Rufus::Scheduler.parse(key)
            Soles.logger.info "Set up #{klass.to_s} to produce every #{period.to_s}"
            setup_job(klass.to_s, period, &options[:block])
          else
            Soles.logger.info "Didn't get a setup option for #{klass.to_s} (#{options.inspect})"
          end
        else
          Soles.logger.info "No production options for #{klass.to_s} (#{options.inspect})"
        end
      end
    end
    Thread.abort_on_exception = abort

    @setup_jobs = true
  end

  def setup_job(name, delay, &block)
    case delay
    when Float, Integer, ActiveSupport::Duration
      every("15s") do
        zk = Soles.configuration.zookeeper
        key = "/jobs/#{name}/last_run"
        zk.mkdir_p key if not zk.exists? key
        data, _stat = zk.get(key)
        now = Time.now.utc.to_i
        if not data or now >= data.to_i
          Soles.logger.info "Running #{name}"
          begin
            block.call
          rescue StandardError => e
            Bugsnag.notify e
          ensure
            zk.set(key, (Time.now.utc.to_i + delay).to_s)
          end
        else
          Soles.logger.info "Not running #{name}: next run timestamp is #{data.to_f}, now is #{now}"
        end
      end
    when Rufus::Scheduler::CronLine
      cron(delay, &block)
    else
      raise "Unknown delay type: #{delay.inspect} (#{delay.class})"
    end
  end
end

def setup_scheduler!
  # First, setup the scheduler. Every worker will have a hot scheduler ready to roll.
  Soles.configuration.scheduler = PollingZKScheduler.new(Soles.configuration.zookeeper)

  # Boot a thread that will attempt to take control of the scheduling every 60 sec
  # If we're able to acquire the scheduler lock, then we start scheduling.
  Thread.new do
    scheduler = Soles.configuration.scheduler
    while true
      # If we were able to set up scheduling, here we go!
      if scheduler.lock
        scheduler.send(:start) unless scheduler.up?
        scheduler.setup_jobs!
      else
        Soles.logger.info "Scheduler was unable to start - another process holds the scheduler lock. Trying again in 60 sec."
      end
      sleep 60
    end
  end
end

Thread.abort_on_exception = true
setup_scheduler! if Sidekiq.server? && !Kraken.standalone?
