# frozen_string_literal: true

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

  s.required_ruby_version = ">= 3.0"

  s.metadata["changelog_uri"] = "#{s.homepage}/blob/master/CHANGELOG.md"

  # Ship only what is needed at runtime: the files tracked by git, minus
  # tests, CI settings and development files.
  gemspec = File.basename(__FILE__)
  s.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ .git Gemfile Rakefile])
    end
  end
  s.bindir        = "exe"
  s.executables   = s.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "rubyzip", ">= 2.3", "< 4.0"
end
