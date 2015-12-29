require 'forwardable'
require 'json'
require 'tempfile'

module AbfWorker::Runners
  class Rpm
    extend Forwardable

    attr_accessor :script_runner,
                  :can_run,
                  :packages,
                  :exit_status

    def_delegators :@worker, :logger

    def initialize(worker, options)
      @worker               = worker
      @cmd_params           = options['cmd_params']
      @platform             = options['platform']
      @build_requires       = options['build_requires']
      @include_repos        = options['include_repos']
      @user                 = options['user']
      @rerun_tests          = options['rerun_tests'].to_s
      @can_run              = true
      @packages             = []
    end

    def run_script
      @script_runner = Thread.new do
        begin
          include_repos_names = []
          include_repos_urls = []
          @include_repos.each do |key, value|
            include_repos_names << key
            include_repos_urls << value
          end
          params = {
            'REPO_NAMES'    => include_repos_names.join(' '),
            'REPO_URL'      => include_repos_urls.join(' '),
            'UNAME'         => @user['uname'],
            'EMAIL'         => @user['email'],
            'PLATFORM_ARCH' => @platform['arch']
          }
          @cmd_params.merge!(params)
          @cmd_params.each { |key, value| @cmd_params[key] = value.to_s }

          process = IO.popen(@cmd_params, "/bin/bash /build-rpm.sh", "r") do |io| 
            Process.wait(io.pid) 
            @exit_status = $?.exitstatus
          end
          @worker.status = @exit_status == 0 ? AbfWorker::BaseWorker::BUILD_COMPLETED : AbfWorker::BaseWorker::BUILD_FAILED
          save_results
        rescue Exception => e
          puts e.to_s
        end
      end
      Thread.current[:subthreads] << @script_runner
      @script_runner.join if @can_run
    end

    private

    def save_results
      container_data = "#{APP_CONFIG['output_folder']}/container_data.json"
      if File.exists?(container_data)
        @packages = JSON.parse(IO.read(container_data)).select{ |p| p['name'] }
        File.delete container_data
      end

      if @rerun_tests != 'true' && @packages.size < 2
        @worker.status = AbfWorker::BaseWorker::BUILD_FAILED
      end
    end

  end
end