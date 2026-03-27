begin
  require "rubygems"
  require "bundler/setup"
rescue LoadError
  warn "couldn't load bundler:"
  warn "  #{$!}"
end

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new do |t|
  t.verbose    = false
  t.pattern    = "spec/**/*_spec.rb"
  t.rspec_opts = "--color --format=p"
end

task :default => :spec
