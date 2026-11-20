# frozen_string_literal: true

require 'zip'
require 'fileutils'
require_relative 'epzip/version'

class Epzip
  class Error < StandardError; end

  MIMETYPE_FILENAME = 'mimetype'
  MIMETYPE_CONTENT  = 'application/epub+zip'

  def self.zip(epubdir, epubfile = nil)
    unless File.exist?(epubdir)
      raise ArgumentError, "No such directory -- #{epubdir}"
    end

    epubfile ||= epubdir + ".epub"

    Zip::OutputStream.open(epubfile) do |zos|
      # The mimetype entry must come first and be stored uncompressed.
      zos.put_next_entry(mimetype_entry(epubfile), nil, nil, Zip::Entry::STORED)
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

        filepath = File.expand_path(File.join(root, entry.name))
        # Guard against Zip Slip: reject entries that would escape the target
        # directory instead of relying on rubyzip, which either skips its own
        # check (2.x, explicit destination path) or only warns (3.x).
        unless filepath.start_with?(root + File::SEPARATOR)
          raise Error, "Illegal entry name -- #{entry.name}"
        end

        FileUtils.mkdir_p(File.dirname(filepath))
        extract_entry(entry, root, filepath)
      end
    end

    epubdir
  end

  # EPUB (OCF) forbids an extra field on the mimetype entry. rubyzip 3.x adds
  # a Zip64 placeholder to every streamed entry whose size is not yet known,
  # so declare the size up front.
  def self.mimetype_entry(epubfile)
    entry = Zip::Entry.new(epubfile, MIMETYPE_FILENAME)
    entry.compression_method = Zip::Entry::STORED
    entry.size = MIMETYPE_CONTENT.bytesize
    entry
  end
  private_class_method :mimetype_entry

  # Zip::Entry#extract takes the destination path in rubyzip 2.x, and an entry
  # path relative to +destination_directory+ in rubyzip 3.x.
  RUBYZIP_V3_EXTRACT = Zip::Entry.instance_method(:extract).parameters
                                 .any? { |_, name| name == :destination_directory }
  private_constant :RUBYZIP_V3_EXTRACT

  def self.extract_entry(entry, root, filepath)
    if RUBYZIP_V3_EXTRACT
      entry.extract(entry.name, destination_directory: root) { true }
    else
      entry.extract(filepath) { true }
    end
  end
  private_class_method :extract_entry
end
