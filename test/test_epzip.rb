require 'helper'
require 'tmpdir'
require 'fileutils'

class TestEpzip < Test::Unit::TestCase
  def test_zip_should_use_existed_dir
    assert_raise ArgumentError do
      Epzip.zip("unknown_dir")
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

      %w[META-INF/container.xml OEBPS/content.opf OEBPS/img.bin].each do |rel|
        assert File.exist?(File.join(dest, rel)), "#{rel} extracted"
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
end
