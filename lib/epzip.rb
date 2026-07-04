require 'zip'
require 'fileutils'
require 'epzip/version'

class Epzip
  MIMETYPE_FILENAME = 'mimetype'.freeze
  MIMETYPE_CONTENT  = 'application/epub+zip'.freeze

  def self.zip(epubdir, epubfile = nil)
    unless File.exist?(epubdir)
      raise ArgumentError, "No such directory -- #{epubdir}"
    end

    epubfile ||= epubdir + ".epub"

    Zip::OutputStream.open(epubfile) do |zos|
      # The mimetype entry must come first and be stored uncompressed.
      zos.put_next_entry(MIMETYPE_FILENAME, nil, nil, Zip::Entry::STORED)
      zos << MIMETYPE_CONTENT

      Dir.chdir(epubdir) do
        Dir.glob("**/*") do |path|
          next if path == MIMETYPE_FILENAME
          next unless File.file?(path)

          zos.put_next_entry(path)
          zos << File.binread(path)
        end
      end
    end

    epubfile
  end

  def self.unzip(epubfile, epubdir = nil)
    epubdir ||= Dir.pwd
    FileUtils.mkdir_p(epubdir)

    root = File.expand_path(epubdir)

    Zip::File.open(epubfile) do |zip|
      zip.each do |entry|
        next if entry.name_is_directory?

        filepath = File.expand_path(File.join(epubdir, entry.name))
        # Guard against Zip Slip: rubyzip skips its own name check when an
        # explicit destination path is given, so reject entries that would
        # escape the target directory.
        unless filepath == root || filepath.start_with?(root + File::SEPARATOR)
          raise ArgumentError, "Illegal entry name -- #{entry.name}"
        end

        FileUtils.mkdir_p(File.dirname(filepath))
        entry.extract(filepath) { true }
      end
    end

    epubdir
  end
end
