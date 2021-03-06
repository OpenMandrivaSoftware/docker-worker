require 'time'

module DockerRpmWorker::Inspectors
  class LiveInspector
    CHECK_INTERVAL = 60 # 60 sec

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
      @worker.status = DockerRpmWorker::BaseWorker::BUILD_CANCELED
      runner = @worker.runner
      script_pid = runner.script_pid
      Process.kill(:TERM, script_pid) if script_pid
    end

    def status
      return 'USR1' if @worker.shutdown
      q = 'abfworker::'
      q << 'rpm'
      q << '-worker-'
      q << @worker.build_id.to_s
      q << '::live-inspector'
      DockerRpmWorker::Models::Job.status(key: q)
    end

  end
end
