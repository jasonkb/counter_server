# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "counter_server/version"

Gem::Specification.new do |s|
  s.name        = "counter_server"
  s.version     = CounterServer::VERSION
  s.authors     = ["Jason Katz-Brown"]
  s.email       = ["jasonkb@airbnb.com"]
  s.homepage    = ""
  s.summary     = %q{Counter Server -- listens for statsd-like counts and aggregates them in Redis}
  s.description = %q{Count things, saves in Redis}

  s.rubyforge_project = "counter_server"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "eventmachine"
  s.add_runtime_dependency "redis"
end
