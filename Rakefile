require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.warning = true
  t.verbose = true
end

namespace :test do
  task :all do
    %w(rails32 rails40 rails41 rails42 rails50).each do |gemfile|
      sh "BUNDLE_GEMFILE='Gemfile.#{gemfile}' bundle --quiet"
      sh "BUNDLE_GEMFILE='Gemfile.#{gemfile}' bundle exec rake test"
    end
  end
end
