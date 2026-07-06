# -*- encoding: utf-8 -*-

require_relative "lib/epzip/version"

Gem::Specification.new do |s|
  s.name        = "epzip"
  s.version     = Epzip::VERSION
  s.authors     = ["Masayoshi Takahashi"]
  s.email       = "takahashimm@gmail.com"
  s.homepage    = "https://github.com/takahashim/epzip"
  s.summary     = "simple EPUB packing tool"
  s.description = "epzip is an EPUB packing tool. It's just only to do 'zip.'"
  s.license     = "MIT"

  s.required_ruby_version = ">= 2.6"

  s.files       = `git ls-files -z`.split("\x0")
  s.executables = ["epunzip", "epzip"]
  s.require_paths = ["lib"]

  s.add_runtime_dependency "rubyzip", ">= 1.0", "< 4.0"
end
