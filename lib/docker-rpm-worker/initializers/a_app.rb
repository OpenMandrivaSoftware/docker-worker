require 'config_for'

Thread.abort_on_exception = true

ROOT = File.dirname(__FILE__) + '/../../../'

APP_CONFIG = ConfigFor.load_config!("#{ROOT}/config", 'application', 'common')