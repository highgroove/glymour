# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "glymour/version"

Gem::Specification.new do |s|
  s.name        = "glymour"
  s.version     = Glymour::VERSION
  s.authors     = ["Brian Stanwyck"]
  s.email       = ["brian.stanwyck@ncf.edu"]
  s.homepage    = ""
  s.summary     = %q{A gem for supervised Bayesian net structure learning}
  s.description = %q{Implements supervised Bayesian structure learning, as well as extra tools to help train a Bayesian net using ActiveRecord data}
  
  s.add_development_dependency "rspec"
  s.add_development_dependency "pry"
  s.add_development_dependency "ruby-debug"
  
  s.add_dependency 'rgl'
  s.add_dependency 'sbn'
  s.add_dependency 'rinruby'

  s.rubyforge_project = "glymour"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
