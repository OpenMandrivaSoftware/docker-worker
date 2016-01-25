require 'json'

module DockerRpmWorker::Runners
  class Rpm

    attr_accessor :packages,
                  :exit_status,
                  :script_pid

    def initialize(worker, options)
      @worker               = worker
      @cmd_params           = options['cmd_params']
      @platform             = options['platform']
      @build_requires       = options['build_requires']
      @include_repos        = options['include_repos']
      @user                 = options['user']
      @rerun_tests          = options['rerun_tests'].to_s
      @packages             = []
      @script_pid           = nil
    end

    def run_script
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

      if @worker.status != DockerRpmWorker::BaseWorker::BUILD_CANCELED
        process = IO.popen(@cmd_params, '/bin/bash /' + @platform['type'] + '/build-rpm.sh', 'r', :err=>[:child, :out]) do |io|
          @script_pid = io.pid
          while true
            begin
              break if io.eof
              line = io.gets
              puts line
              @worker.logger.log(line)
            rescue => e
              break
            end
          end
          Process.wait(io.pid)
          @exit_status = $?.exitstatus
        end
        if @worker.status != DockerRpmWorker::BaseWorker::BUILD_CANCELED
          @worker.status = @exit_status == 0 ? DockerRpmWorker::BaseWorker::BUILD_COMPLETED : DockerRpmWorker::BaseWorker::BUILD_FAILED
        end
        save_results
      end
    end

    private

    def save_results
      container_data = "#{APP_CONFIG['output_folder']}/container_data.json"
      if File.exists?(container_data)
        @packages = JSON.parse(IO.read(container_data)).select{ |p| p['name'] }
        File.delete container_data
      end

      if @rerun_tests != 'true' && @packages.size < 2
        @worker.status = DockerRpmWorker::BaseWorker::BUILD_FAILED
      end
    end

  end
end
