module AbfWorker
  class LiveLogger
    LOG_DUMP_INTERVAL = 30 #30 seconds

    def initialize(key_name)
      @key_name  = key_name
      @log_mutex = Mutex.new
      @buffer    = ""

      Thread.current[:subthreads] << Thread.new do
        loop do
          sleep LOG_DUMP_INTERVAL
          next if @buffer.empty?
          @log_mutex.synchronize do
            AbfWorker::Models::Job.logs({name: @key_name, logs: @buffer})
          end
        end
      end
    end

    def log(message)
      @log_mutex.synchronize do
        buffer << message
      end
    end

  end
end
