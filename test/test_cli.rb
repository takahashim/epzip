# frozen_string_literal: true

require 'helper'
require 'open3'
require 'rbconfig'

# Runs exe/epzip and exe/epunzip as separate processes.
class TestCli < Test::Unit::TestCase
  include EpzipTestHelper

  ROOT = File.expand_path("..", __dir__)

  def setup
    @base = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@base)
  end

  def test_epzip_creates_epub
    src = make_book(@base)
    epub = File.join(@base, "out.epub")

    _out, err, status = run_command("epzip", src, epub)

    assert status.success?, err
    assert_equal "", err
    assert_equal "mimetype", Zip::File.open(epub) { |zip| zip.entries.first.name }
  end

  def test_epzip_uses_default_filename
    src = make_book(@base)

    _out, err, status = run_command("epzip", src)

    assert status.success?, err
    assert File.file?(src + ".epub")
  end

  def test_epzip_shows_usage_without_arguments
    assert_failure "usage: epzip <srcdir> [filename]", run_command("epzip")
  end

  def test_epzip_shows_usage_with_too_many_arguments
    assert_failure "usage: epzip <srcdir> [filename]", run_command("epzip", "a", "b", "c")
  end

  def test_epzip_fails_for_missing_source_dir
    missing = File.join(@base, "missing")

    assert_failure "No such directory: #{missing}", run_command("epzip", missing)
  end

  def test_epzip_does_not_overwrite_existing_file
    src = make_book(@base)
    epub = File.join(@base, "out.epub")
    File.write(epub, "keep me")

    assert_failure "File already exists: #{epub}", run_command("epzip", src, epub)
    assert_equal "keep me", File.read(epub)
  end

  def test_epzip_fails_for_file_as_source_dir
    file = File.join(@base, "file")
    File.write(file, "not a directory")

    assert_failure "No such directory: #{file}", run_command("epzip", file)
  end

  def test_epzip_reports_symlink_to_outside_of_source_dir
    src = make_book(@base)
    File.write(File.join(@base, "secret.txt"), "secret")
    symlink(File.join(@base, "secret.txt"), File.join(src, "notes.txt"))

    assert_failure "Symbolic link to outside of the source directory -- notes.txt",
                   run_command("epzip", src)
    assert !File.exist?(src + ".epub")
  end

  def test_epunzip_extracts_into_current_directory_by_default
    epub = Epzip.zip(make_book(@base), File.join(@base, "out.epub"))
    cwd = File.join(@base, "cwd")
    FileUtils.mkdir_p(cwd)

    _out, err, status = run_command("epunzip", epub, chdir: cwd)

    assert status.success?, err
    assert_equal %w[META-INF OEBPS mimetype], Dir.children(cwd).sort
  end

  def test_epunzip_does_not_overwrite_file_in_current_directory
    epub = Epzip.zip(make_book(@base), File.join(@base, "out.epub"))
    cwd = File.join(@base, "cwd")
    FileUtils.mkdir_p(cwd)
    File.write(File.join(cwd, "mimetype"), "keep me")

    _out, err, status = run_command("epunzip", epub, chdir: cwd)

    assert_equal 1, status.exitstatus
    assert_match(/\AFile already exists -- .*mimetype\n\z/, err)
    assert_equal %w[mimetype], Dir.children(cwd)
    assert_equal "keep me", File.read(File.join(cwd, "mimetype"))
  end

  def test_epunzip_extracts_epub
    epub = Epzip.zip(make_book(@base), File.join(@base, "out.epub"))
    dest = File.join(@base, "unpacked")

    _out, err, status = run_command("epunzip", epub, dest)

    assert status.success?, err
    assert_equal "", err
    assert_equal "<package/>\n", File.read(File.join(dest, "OEBPS", "content.opf"))
  end

  def test_epunzip_shows_usage_without_arguments
    assert_failure "usage: epunzip <filename> [targetdir]", run_command("epunzip")
  end

  def test_epunzip_fails_for_missing_file
    missing = File.join(@base, "missing.epub")

    assert_failure "No such file: #{missing}", run_command("epunzip", missing)
  end

  def test_epunzip_does_not_extract_into_existing_dir
    epub = Epzip.zip(make_book(@base), File.join(@base, "out.epub"))
    dest = File.join(@base, "unpacked")
    FileUtils.mkdir_p(dest)

    assert_failure "Directory already exists: #{dest}", run_command("epunzip", epub, dest)
    assert_equal [], Dir.children(dest)
  end

  def test_epunzip_reports_broken_archive_without_backtrace
    broken = File.join(@base, "broken.epub")
    File.write(broken, "this is not a zip file\n")
    dest = File.join(@base, "unpacked")

    _out, err, status = run_command("epunzip", broken, dest)

    assert_equal 1, status.exitstatus
    assert_equal 1, err.lines.size, "a single message, not a backtrace: #{err}"
    assert !File.exist?(dest), "must not leave an empty target directory"
  end

  def test_epunzip_reports_illegal_entry_without_backtrace
    evil = File.join(@base, "evil.epub")
    Zip::File.open(evil, create: true) do |zip|
      zip.get_output_stream("../escaped.txt") { |os| os.write("pwned") }
    end

    result = run_command("epunzip", evil, File.join(@base, "unpacked"))

    assert_failure "Illegal entry name -- ../escaped.txt", result
    assert !File.exist?(File.join(@base, "escaped.txt")), "must not write outside dest"
  end

  private

  def run_command(name, *args, chdir: Dir.pwd)
    Open3.capture3(RbConfig.ruby, "-I", File.join(ROOT, "lib"),
                   File.join(ROOT, "exe", name), *args, chdir: chdir)
  end

  def assert_failure(message, result)
    out, err, status = result
    assert_equal 1, status.exitstatus
    assert_equal "#{message}\n", err
    assert_equal "", out
  end
end
