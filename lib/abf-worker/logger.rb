module AbfWorker
  class LiveLogger
    LOG_DUMP_INTERVAL = 5 #30 seconds

    def initialize(key_name)
      @key_name  = key_name
      @buffer    = ""
      Thread.current[:subthreads] << Thread.new do
        loop do
          sleep LOG_DUMP_INTERVAL
          puts @buffer
          next if @buffer.empty?
          AbfWorker::Models::Job.logs({name: @key_name, logs: @buffer})
        end
      end
    end

    def log(message)
      @buffer << message
    end

  end
end
