module AbfWorker
  class LiveLogger
    LOG_DUMP_INTERVAL = 10 #30 seconds
    LOG_SIZE_LIMIT    = 100 # 100 lines
    def initialize(key_name)
      @key_name  = key_name
      @buffer    = []
      @log_mutex = Mutex.new
      Thread.current[:subthreads] << Thread.new do
        loop do
          sleep LOG_DUMP_INTERVAL
          next if @buffer.empty?
          str = @buffer.join
          @log_mutex.synchronize do
            AbfWorker::Models::Job.logs({name: @key_name, logs: str})
          end
        end
      end
    end

    def log(message)
      line = message.to_s
      unless line.empty?
        @log_mutex.synchronize do
          @buffer.shift if @buffer.size > LOG_SIZE_LIMIT
          @buffer << line
        end
      end
    end

  end
end
