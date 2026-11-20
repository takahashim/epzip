# frozen_string_literal: true

require 'test/unit'
require 'tmpdir'
require 'fileutils'
require 'epzip'

module EpzipTestHelper
  # Creates a minimal EPUB resource directory under +base+ and returns its path.
  # Pass +mimetype+ to also put a mimetype file with that content in it.
  def make_book(base, mimetype: nil)
    src = File.join(base, "book")
    FileUtils.mkdir_p(File.join(src, "META-INF"))
    FileUtils.mkdir_p(File.join(src, "OEBPS"))
    File.write(File.join(src, "META-INF", "container.xml"), "<container/>\n")
    File.write(File.join(src, "OEBPS", "content.opf"), "<package/>\n")
    File.write(File.join(src, "mimetype"), mimetype) if mimetype
    src
  end

  # Creates a symbolic link, or omits the test where they are not available.
  def symlink(target, link)
    File.symlink(target, link)
  rescue NotImplementedError, Errno::EACCES
    omit "symbolic links are not available"
  end
end
