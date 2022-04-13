task :default => :spec
require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/test_*.rb']
end

task :server do
  require 'puma'
  require 'puma/configuration'
  require 'puma/events'
  require 'puma/plugin/kubernetes'

  configuration = Puma::Configuration.new do |config|
    config.bind 'tcp://127.0.0.1:0'
    config.kubernetes_url 'tcp://127.0.0.1:9494'
    config.plugin 'kubernetes'
    config.workers 1
    config.app do |_env|
      [200, {}, ['hello world']]
    end
  end

  events = Puma::Events.new STDOUT, STDERR
  launcher = Puma::Launcher.new(configuration, events: events)
  launcher.run
end

task default: :test
