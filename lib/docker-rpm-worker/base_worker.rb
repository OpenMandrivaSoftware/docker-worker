require 'docker-rpm-worker/live_logger'
require 'docker-rpm-worker/file_logger'
require 'cgi'
require 'net/http'

module DockerRpmWorker
  class BaseWorker

    BUILD_COMPLETED = 0
    BUILD_FAILED    = 1
    BUILD_PENDING   = 2
    BUILD_STARTED   = 3
    BUILD_CANCELED  = 4
    TESTS_FAILED    = 5
    TWO_IN_THE_TWENTIETH = 2**20

    attr_accessor :status,
                  :build_id,
                  :worker_id,
                  :live_inspector,
                  :shutdown

    def initialize(options)
      Thread.current[:subthreads] ||= []
      @shutdown = false
      @options  = options
      @extra    = options['extra'] || {}
      @skip_feedback  = options['skip_feedback'] || false
      @status     = BUILD_STARTED
      @build_id   = options['id']
      @worker_id  = Process.ppid
      update_build_status_on_abf({hostname: Socket.gethostname})
    end

    def perform
      @runner.run_script
      send_results
    end

    protected

    def init_file_logger(file_path)
      @file_logger = DockerRpmWorker::FileLogger.new(file_path)
    end

    def init_live_logger(key_name)
      @live_logger = DockerRpmWorker::LiveLogger.new(key_name)
    end

    def file_store_token
      @file_store_token ||= APP_CONFIG['file_store']['token']
    end

    def upload_file_to_file_store(path, file_name, output_curl_log = true)
      path_to_file = path + '/' + file_name
      return unless File.file?(path_to_file)

      # Compress the log when file size more than 10MB
      file_size = (File.size(path_to_file).to_f / TWO_IN_THE_TWENTIETH).round(2)
      if file_name =~ /.log$/ && file_size >= 10
        system "tar -zcvf #{path_to_file}.tar.gz #{path_to_file}"
        File.delete path_to_file
        path_to_file << '.tar.gz'
        file_name << '.tar.gz'
      end

      sha1 = Digest::SHA1.file(path_to_file).hexdigest

      # curl --user myuser@gmail.com:mypass -POST -F "file_store[file]=@files/archive.zip" http://file-store.rosalinux.ru/api/v1/file_stores.json
      if %x[ curl #{APP_CONFIG['file_store']['url']}.json?hash=#{sha1} ] == '[]'
        command = 'curl --verbose --user '
        command << file_store_token
        command << ': -POST -F "file_store[file]=@'
        command << path_to_file
        command << ';filename=' + CGI.escape(file_name) + '" '
        command << APP_CONFIG['file_store']['create_url']
        command << ' --connect-timeout 5 --retry 5'
        if output_curl_log
          command << ' >> ' + APP_CONFIG['output_folder'] + '/curl.log 2>&1'
        end
        %x[ #{command} ]
      end

      # File.delete path_to_file
      system "sudo rm -rf #{path_to_file}"
      {:sha1 => sha1, :file_name => file_name, :size => file_size}
    end

    def upload_results_to_file_store
      uploaded = []
      results_folder = APP_CONFIG["output_folder"]
      if File.exists?(results_folder) && File.directory?(results_folder)
        Dir.new(results_folder).entries.each do |f|
          uploaded << upload_file_to_file_store(results_folder, f)
        end
      end
      uploaded << upload_file_to_file_store(results_folder, 'curl.log', false)
      uploaded.compact
    end

    def initialize_live_inspector(time_living)
      @live_inspector = DockerRpmWorker::Inspectors::LiveInspector.new(self, time_living)
      @live_inspector.run
    end

    def update_build_status_on_abf(args = {}, force = false)
      if !@skip_feedback || force
        if APP_CONFIG["abf_url"]
          url = URI(APP_CONFIG["abf_url"]) rescue nil
          if url
            loop do
              code = (Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == 'https') do |http|
                http.head("/").code
              end rescue 0).to_i
              break if code >= 200 and code < 400
              sleep 10
            end
          end
        end
        worker_args = [{
          id:     @build_id,
          status: @status,
          extra:  @extra
        }.merge(args)]

        DockerRpmWorker::Models::Job.feedback(
          worker_queue: @observer_queue,
          worker_class: @observer_class,
          worker_args:  worker_args
        )

      end
    end
      
  end
end
