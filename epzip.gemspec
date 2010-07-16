# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{epzip}
  s.version = "0.6.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Masayoshi Takahashi"]
  s.date = %q{2010-07-16}
  s.default_executable = %q{epzip}
  s.description = %q{epzip is EPUB packing tool. It's just only to do 'zip.'}
  s.email = %q{takahashimm@gmail.com}
  s.executables = ["epzip"]
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "bin/epzip",
     "epzip.gemspec",
     "lib/epzip.rb",
     "test/helper.rb",
     "test/test_epzip.rb"
  ]
  s.homepage = %q{http://github.com/takahashim/epzip}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{simple EPUB packing tool}
  s.test_files = [
    "test/helper.rb",
     "test/test_epzip.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

