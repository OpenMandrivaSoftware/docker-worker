require 'securerandom'
require 'socket'
require 'docker-rpm-worker/models/job'

module DockerRpmWorker
  class TaskManager

    def initialize
      @shutdown = false
      @worker_thread = nil
      @pid      = Process.pid
      @uid      = SecureRandom.hex
    end

    def run
      Signal.trap("USR1") { stop_and_clean }
      loop do 
        find_new_job unless shutdown?
        if shutdown? and not @worker_thread.alive?
          return
        end
        cleanup_worker_thread
        send_statistics
        sleep 10
      end
    end

    private

    # only for RPM
    def send_statistics
      DockerRpmWorker::Models::Job.statistics({
        uid:          @uid,
        worker_count: 1,
        busy_workers: (@worker_thread and @worker_thread.alive?) ? 1 : 0,
        host:         Socket.gethostname
      })
    end

    def cleanup_worker_thread
      return if @worker_thread.nil? or (@worker_thread.alive? and not @shutdown)
      @worker_thread[:subthreads].each { |t| t.kill }
      @worker_thread.kill
      @worker_thread = nil
    end

    def stop_and_clean
      @shutdown = true
    end

    def find_new_job
      return if @worker_thread and @worker_thread.alive?
      return unless job = DockerRpmWorker::Models::Job.shift

      @worker_thread = Thread.new do
        worker = DockerRpmWorker::RpmWorker.new(job.worker_args[0])
        Thread.current[:worker] = worker

        worker.perform
      end
    end

    def shutdown?
      @shutdown
    end
  end
end
