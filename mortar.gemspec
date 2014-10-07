$:.unshift File.expand_path("../lib", __FILE__)
require "mortar/version"

Gem::Specification.new do |gem|
  gem.name    = "mortar"
  gem.version = Mortar::VERSION

  gem.author      = "Mortar Data"
  gem.email       = "support@mortardata.com"
  gem.homepage    = "http://mortardata.com/"
  gem.summary     = "Client library and CLI to interact with the Mortar service."
  gem.description = "Client library and command-line tool to interact with the Mortar service."
  gem.executables = "mortar"
  gem.platform    = Gem::Platform::RUBY
  gem.required_ruby_version = '>=1.8.7'
  
  gem.files = %x{ git ls-files }.split("\n").select { |d| d =~ %r{^(License|README|bin/|data/|ext/|lib/|spec/|test/|css/|js/|flash/)} }
  
  gem.add_runtime_dependency  "rdoc", ">= 4.0.0"
  gem.add_runtime_dependency  "mortar-api-ruby", "~> 0.8.9"
  gem.add_runtime_dependency  "netrc",           "~> 0.7"
  gem.add_runtime_dependency  "launchy",         "~> 2.1"
  gem.add_runtime_dependency  "parseconfig",     "~> 1.0.2"
  gem.add_runtime_dependency  "aws-sdk",         "~> 1.0"
  # specifically use version 1.5.0 as it is required for aws-sdk to work on ruby 1.8.7
  gem.add_runtime_dependency  "nokogiri",        "~> 1.5.0"


  gem.add_development_dependency 'excon', '~>0.28'
  gem.add_development_dependency "fakefs", '~> 0.4.2'
  gem.add_development_dependency "gem-release"
  # rake is pinned as version 10.2 requires >= ruby 1.9
  gem.add_development_dependency "rake",   '~> 10.1.1'
  gem.add_development_dependency "rr"
  # Use latest 2.x for rspec.  3.x breaks test configuration and various assertions
  gem.add_development_dependency "rspec", '~> 2.0'

end
