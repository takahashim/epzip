# frozen_string_literal: true

require 'helper'
require 'tmpdir'
require 'fileutils'

class TestEpzip < Test::Unit::TestCase
  def test_zip_should_use_existed_dir
    assert_raise ArgumentError do
      Epzip.zip("unknown_dir")
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
