class ZookeptScheduler < ::Rufus::Scheduler
  def initialize(zookeeper, opts = {})
    @zk = zookeeper
    super(opts)
  end

  def lock
    locker.lock # returns true if the lock was acquired, false else
  end

  def locker
    @zk_locker ||= @zk.exclusive_locker('scheduler')
  end

  def unlock
    locker.unlock
  end

  def confirm_lock
    return false if down?
    locker.assert!
  rescue ZK::Exceptions::LockAssertionFailedError
    # we've lost the lock, shutdown (and return false to at least prevent
    # this job from triggering
    shutdown
    false
  end

  def on_error(job, err)
    Bugsnag.notify err
    super
  end
end
