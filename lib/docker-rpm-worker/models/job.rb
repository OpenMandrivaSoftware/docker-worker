require 'docker-rpm-worker/models/base'

module DockerRpmWorker::Models
  class Job < DockerRpmWorker::Models::Base

    # A transformer. All data from an API will be transformed to 
    # BaseStat instance.
    class JobStat < APISmith::Smash
      property :worker_args,   transformer: :to_a
      property :worker_queue,  transformer: :to_s
      property :worker_class,  transformer: :to_s
    end # BuildListStat

    class BaseStat < APISmith::Smash
      property :job, transformer: JobStat
    end # BaseStat

    class Status < APISmith::Smash
      property :status,  transformer: :to_s
    end # Status

    def self.shift
      new.get('/shift',
              extra_query: {
                platforms: APP_CONFIG['supported_platforms'],
                arches:    APP_CONFIG['supported_arches']
              },
              transform: BaseStat).job
    rescue => e
      # We don't raise exception, because high classes don't rescue it.
      # DockerRpmWorker::BaseWorker.send_error(e)
      return nil
    end

    def self.status(options = {})
      new.get('/status', extra_query: options, transform: Status).status
    rescue => e
      # We don't raise exception, because high classes don't rescue it.
      # DockerRpmWorker::BaseWorker.send_error(e)
      return nil
    end

    def self.logs(options = {})
      new.put '/logs', extra_body: options
    rescue => e
      # We don't raise exception, because high classes don't rescue it.
      # DockerRpmWorker::BaseWorker.send_error(e)
      return nil
    end

    def self.statistics(options = {})
      new.put '/statistics', extra_body: options
    rescue => e
      # We don't raise exception, because high classes don't rescue it.
      return nil
    end

    def self.feedback(options = {})
      tries ||= 5
      new.put '/feedback', extra_body: options
    rescue => e
      sleep 2
      retry unless (tries -= 1).zero?
      return nil
    end

    protected

    def endpoint
      "jobs"
    end

  end
end