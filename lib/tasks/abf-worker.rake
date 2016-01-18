$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'docker-rpm-worker'

namespace :abf_worker do
  desc 'Start docker rpm worker'
  task :start do
    DockerRpmWorker::TaskManager.new.run
  end
end
