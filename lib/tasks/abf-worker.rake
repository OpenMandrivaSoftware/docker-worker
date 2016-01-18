$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'abf-worker'
# require 'airbrake/tasks'

namespace :abf_worker do

  task :lock do
    system "lockfile -r 0 #{ENV['PIDFILE']} 1>/dev/null 2>&1" if ENV['PIDFILE']
  end

  desc 'Start ABF Worker service (rpm)'
  task start: ['abf_worker:lock'] do
    AbfWorker::TaskManager.new.run
  end

  desc 'Stop ABF Worker service'
  task :stop do
    folder = "#{ROOT}/pids/"
    %x[ ls -1 #{folder} ].split("\n").each do |pid|
      system "kill -USR1 #{pid}" if pid =~ /^[\d]+$/
    end
    loop do
      pids = %x[ ls -1 #{folder} ].split("\n").select{ |pid| pid =~ /^[\d]+$/ }
      pids.each do |pid|
        system "rm -f #{folder}/#{pid}" if %x[ ps aux | grep #{pid} | grep -v grep ] == ''
      end
      break if pids.empty?
      sleep 5
    end
    puts "==> ABF Worker service has been stopped [OK]"
  end

end
