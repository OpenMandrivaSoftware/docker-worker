module DockerRpmWorker
  class FileLogger
    def initialize(file_path)
      @file = File.open(file_path, "w") rescue nil
    end

    def close
      @file.close rescue nil
    end

    def log(message)
      return unless @file
      line = message.to_s
      @file.puts(line) unless line.empty? rescue nil
    end

  end
end
