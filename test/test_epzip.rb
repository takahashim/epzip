# frozen_string_literal: true

require 'helper'

class TestEpzip < Test::Unit::TestCase
  include EpzipTestHelper

  def test_zip_should_use_existed_dir
    assert_raise ArgumentError do
      Epzip.zip("unknown_dir")
    end
  end

  def test_zip_uses_dir_name_with_epub_extension_by_default
    Dir.mktmpdir do |base|
      src = make_book(base)

      assert_equal src + ".epub", Epzip.zip(src)
      assert File.file?(src + ".epub")
    end
  end

  # A real EPUB resource directory has its own mimetype file. It must not be
  # added a second time, and its content must not replace the canonical one.
  def test_zip_does_not_duplicate_mimetype_in_source_dir
    Dir.mktmpdir do |base|
      src = make_book(base, mimetype: "application/epub+zip\n")

      epub = Epzip.zip(src, File.join(base, "out.epub"))

      Zip::File.open(epub) do |zip|
        names = zip.entries.map(&:name)
        assert_equal Epzip::MIMETYPE_FILENAME, names.first
        assert_equal 1, names.count(Epzip::MIMETYPE_FILENAME)
        assert_equal %w[META-INF/container.xml OEBPS/content.opf mimetype], names.sort
        assert_equal Epzip::MIMETYPE_CONTENT, zip.entries.first.get_input_stream.read
      end
    end
  end

  def test_unzip_extracts_into_current_directory_by_default
    Dir.mktmpdir do |base|
      epub = Epzip.zip(make_book(base), File.join(base, "out.epub"))

      dest = File.join(base, "cwd")
      FileUtils.mkdir_p(dest)
      Dir.chdir(dest) do
        assert_equal Dir.pwd, Epzip.unzip(epub)
      end

      assert_equal Epzip::MIMETYPE_CONTENT, File.read(File.join(dest, "mimetype"))
      assert File.file?(File.join(dest, "OEBPS", "content.opf"))
    end
  end

  def test_unzip_does_not_create_target_dir_for_broken_archive
    Dir.mktmpdir do |base|
      broken = File.join(base, "broken.epub")
      File.write(broken, "this is not a zip file\n")

      dest = File.join(base, "out")
      assert_raise Zip::Error do
        Epzip.unzip(broken, dest)
      end
      assert !File.exist?(dest), "must not leave an empty target directory"
    end
  end

  # The target is "out"; "out-evil" shares that prefix but is outside of it.
  def test_unzip_rejects_entry_in_sibling_dir_with_same_prefix
    Dir.mktmpdir do |base|
      evil = File.join(base, "evil.zip")
      Zip::File.open(evil, create: true) do |zip|
        zip.get_output_stream("../out-evil/escaped.txt") { |os| os.write("pwned") }
      end

      assert_raise Epzip::Error do
        Epzip.unzip(evil, File.join(base, "out"))
      end
      assert !File.exist?(File.join(base, "out-evil")), "must not write outside dest"
    end
  end

  def test_unzip_rejects_path_traversal_entry
    Dir.mktmpdir do |base|
      # Craft an archive with an entry that escapes the target directory.
      evil = File.join(base, "evil.zip")
      Zip::File.open(evil, create: true) do |zip|
        zip.get_output_stream("../escaped.txt") { |os| os.write("pwned") }
      end

      dest = File.join(base, "out")
      assert_raise Epzip::Error do
        Epzip.unzip(evil, dest)
      end
      assert !File.exist?(File.join(base, "escaped.txt")), "must not write outside dest"
    end
  end

  def test_zip_and_unzip_roundtrip
    Dir.mktmpdir do |base|
      src = File.join(base, "book")
      FileUtils.mkdir_p(File.join(src, "META-INF"))
      FileUtils.mkdir_p(File.join(src, "OEBPS"))
      File.write(File.join(src, "META-INF", "container.xml"), "<container/>\n")
      File.write(File.join(src, "OEBPS", "content.opf"), "<package/>\n")
      File.binwrite(File.join(src, "OEBPS", "img.bin"), (0..255).to_a.pack("C*"))

      epub = File.join(base, "out.epub")
      assert_equal epub, Epzip.zip(src, epub)
      assert File.exist?(epub)

      dest = File.join(base, "unpacked")
      Epzip.unzip(epub, dest)

      %w[mimetype META-INF/container.xml OEBPS/content.opf OEBPS/img.bin].each do |rel|
        assert File.exist?(File.join(dest, rel)), "#{rel} extracted"
      end
      assert_equal Epzip::MIMETYPE_CONTENT, File.binread(File.join(dest, "mimetype"))
      %w[META-INF/container.xml OEBPS/content.opf OEBPS/img.bin].each do |rel|
        assert_equal File.binread(File.join(src, rel)),
                     File.binread(File.join(dest, rel)),
                     "#{rel} content matches"
      end
    end
  end

  def test_zip_stores_mimetype_first_and_uncompressed
    Dir.mktmpdir do |base|
      src = File.join(base, "book")
      FileUtils.mkdir_p(File.join(src, "OEBPS"))
      File.write(File.join(src, "OEBPS", "content.opf"), "<package/>\n")

      epub = File.join(base, "out.epub")
      Epzip.zip(src, epub)

      Zip::File.open(epub) do |zip|
        first = zip.entries.first
        assert_equal Epzip::MIMETYPE_FILENAME, first.name
        assert_equal Zip::Entry::STORED, first.compression_method
        assert_equal Epzip::MIMETYPE_CONTENT, first.get_input_stream.read
      end
    end
  end

  # EPUB (OCF) requires the mimetype entry to have no extra field, so that
  # "mimetypeapplication/epub+zip" sits at byte 30 of the file.
  def test_zip_writes_mimetype_without_extra_field
    Dir.mktmpdir do |base|
      src = File.join(base, "book")
      FileUtils.mkdir_p(File.join(src, "OEBPS"))
      File.write(File.join(src, "OEBPS", "content.opf"), "<package/>\n")

      epub = File.join(base, "out.epub")
      Epzip.zip(src, epub)

      header = File.binread(epub, 58)
      assert_equal "PK\x03\x04".b, header[0, 4]
      assert_equal 0, header[28, 2].unpack1("v"), "extra field length"
      assert_equal "mimetypeapplication/epub+zip", header[30, 28]
    end
  end
end
