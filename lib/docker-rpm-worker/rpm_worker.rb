require 'docker-rpm-worker/runners/rpm'
require 'docker-rpm-worker/inspectors/live_inspector'

module DockerRpmWorker
  class RpmWorker < BaseWorker

    attr_accessor :runner,
                  :live_logger,
                  :file_logger

    protected

    # Initialize a new RPM worker.
    # @param [Hash] options The hash with options
    def initialize(options)
      @observer_queue = 'rpm_worker_observer'
      @observer_class = 'AbfWorker::RpmWorkerObserver'
      super options
      @runner = DockerRpmWorker::Runners::Rpm.new(self, options)
      init_live_logger("abfworker::rpm-worker-#{@build_id}")
      init_file_logger(APP_CONFIG['output_folder'] + '/build.log')
      initialize_live_inspector options['time_living']
    end

    def send_results
      sha1_s  = @runner.packages.map{ |p| p['sha1'] }
      results = upload_results_to_file_store
      results.select!{ |r| !sha1_s.include?(r[:sha1]) } unless sha1_s.empty?
      update_build_status_on_abf({
        results:      results,
        packages:     @runner.packages,
        exit_status:  @runner.exit_status,
        commit_hash:  (File.read(ENV['HOME'] + '/commit_hash') rescue '').strip
      })
    end

  end

end
