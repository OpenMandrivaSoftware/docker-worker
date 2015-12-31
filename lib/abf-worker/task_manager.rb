require 'securerandom'
require 'socket'
require 'abf-worker/models/job'

module AbfWorker
  class TaskManager

    def initialize
      @shutdown = false
      @worker_thread = nil
      @pid      = Process.pid
      @uid      = SecureRandom.hex
      touch_pid
    end

    def run
      Signal.trap("USR1") { stop_and_clean }
      loop do 
        find_new_job unless shutdown?
        if shutdown?
          remove_pid
          return
        end
        send_statistics
        sleep 10
      end
    rescue => e
      AbfWorker::BaseWorker.send_error(e)
    end

    private

    # only for RPM
    def send_statistics
      AbfWorker::Models::Job.statistics({
        uid:          @uid,
        worker_count: 1,
        busy_workers: (@worker_thread and @worker_thread.alive?) ? 1 : 0,
        host:         Socket.gethostname
      })
    end

    def stop_and_clean
      @shutdown = true
    end

    def find_new_job
      return if @worker_thread and @worker_thread.alive?
      return unless job = AbfWorker::Models::Job.shift

      @worker_thread = Thread.new do
        clazz  = job.worker_class.split('::').inject(Object){ |o,c| o.const_get c }
        worker = clazz.new(job.worker_args[0])

        begin
          worker.perform
        rescue Exception => e
          File.open(ROOT + "error.log", "a") { |f| f.write(e.to_s + "\n"); e.backtrace.each { |b| f.write(b + "\n") } }
        end
      end
    end

    def shutdown?
      @shutdown
    end

    def touch_pid
      path = "#{ROOT}/pids/#{@pid}"
      system "touch #{path}" unless File.exist?(path) 
    end

    def remove_pid
      system "rm -f #{ROOT}/pids/#{@pid}"
    end

  end
end