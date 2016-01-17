require 'time'

module AbfWorker::Inspectors
  class LiveInspector
    CHECK_INTERVAL = 10 # 60 sec

    def initialize(worker, time_living)
      @worker       = worker
      @kill_at      = Time.now + time_living.to_i
    end

    def run
      @thread = Thread.new do
        while true
          begin
            sleep CHECK_INTERVAL
            stop_build if kill_now?
          rescue => e
          end
        end
      end
      Thread.current[:subthreads] << @thread
    end

    private

    def kill_now?
      if @kill_at < Time.now
        return true
      end
      if status == 'USR1'
        true
      else
        false
      end
    end

    def stop_build
      @worker.status = AbfWorker::BaseWorker::BUILD_CANCELED
      runner = @worker.runner
      runner.can_run = false
      runner.script_runner.kill if runner.script_runner
      runner.rollback if runner.respond_to?(:rollback)
    end

    def status
      return 'USR1' if @worker.shutdown
      q = 'abfworker::'
      q << 'rpm'
      q << '-worker-'
      q << @worker.build_id.to_s
      q << '::live-inspector'
      AbfWorker::Models::Job.status(key: q)
    end

  end
end
