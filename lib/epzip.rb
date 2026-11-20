# frozen_string_literal: true

require 'zip'
require 'fileutils'
require_relative 'epzip/version'

class Epzip
  class Error < StandardError; end

  MIMETYPE_FILENAME = 'mimetype'
  MIMETYPE_CONTENT  = 'application/epub+zip'

  # Packs the directory +epubdir+ into +epubfile+ (default: epubdir + ".epub").
  #
  # Raises Epzip::Error if +epubdir+ contains a symbolic link to a file outside
  # of it, so that packing a directory someone else prepared cannot pull in
  # unrelated files.
  def self.zip(epubdir, epubfile = nil)
    Packer.new(epubdir, epubfile).pack
  end

  # Extracts +epubfile+ into +epubdir+ (default: the current directory).
  #
  # Every entry is checked before anything is written. Epzip::Error is raised,
  # and nothing is extracted, if an entry would be written outside of
  # +epubdir+, through a symbolic link that already exists in it, or over an
  # existing file. Pass <tt>overwrite: true</tt> to replace existing files.
  def self.unzip(epubfile, epubdir = nil, overwrite: false)
    Unpacker.new(epubfile, epubdir, overwrite: overwrite).unpack
  end

  class Packer # :nodoc:
    def initialize(epubdir, epubfile)
      unless File.directory?(epubdir)
        raise ArgumentError, "No such directory -- #{epubdir}"
      end

      @epubdir = epubdir
      @epubfile = epubfile || epubdir + ".epub"
    end

    def pack
      # List the files before creating the output, so that a rejected source
      # directory does not leave a partial EPUB behind.
      paths = source_paths

      Zip::OutputStream.open(@epubfile) do |zos|
        # The mimetype entry must come first and be stored uncompressed.
        zos.put_next_entry(mimetype_entry, nil, nil, Zip::Entry::STORED)
        zos << MIMETYPE_CONTENT

        paths.each do |path|
          zos.put_next_entry(path)
          zos << File.binread(File.join(@epubdir, path))
        end
      end

      @epubfile
    end

    private

    # Returns the files to pack, as paths relative to the source directory.
    def source_paths
      root = File.realpath(@epubdir)

      Dir.glob("**/*", base: @epubdir).select do |path|
        next false if path == MIMETYPE_FILENAME

        file = File.join(@epubdir, path)
        # File.file? follows symbolic links, and so would reading the file.
        next false unless File.file?(file)

        unless File.realpath(file).start_with?(root + File::SEPARATOR)
          raise Error, "Symbolic link to outside of the source directory -- #{path}"
        end

        true
      end
    end

    # EPUB (OCF) forbids an extra field on the mimetype entry. rubyzip 3.x adds
    # a Zip64 placeholder to every streamed entry whose size is not yet known,
    # so declare the size up front.
    def mimetype_entry
      entry = Zip::Entry.new(@epubfile, MIMETYPE_FILENAME)
      entry.compression_method = Zip::Entry::STORED
      entry.size = MIMETYPE_CONTENT.bytesize
      entry
    end
  end
  private_constant :Packer

  class Unpacker # :nodoc:
    # Zip::Entry#extract takes the destination path in rubyzip 2.x, and an
    # entry path relative to +destination_directory+ in rubyzip 3.x.
    RUBYZIP_V3_EXTRACT = Zip::Entry.instance_method(:extract).parameters
                                   .any? { |_, name| name == :destination_directory }

    def initialize(epubfile, epubdir, overwrite:)
      @epubfile = epubfile
      @epubdir = epubdir || Dir.pwd
      @root = File.expand_path(@epubdir)
      @overwrite = overwrite
    end

    def unpack
      Zip::File.open(@epubfile) do |zip|
        targets = zip.reject(&:name_is_directory?).map do |entry|
          [entry, target_path(entry)]
        end

        FileUtils.mkdir_p(@root)
        targets.each do |entry, filepath|
          FileUtils.mkdir_p(File.dirname(filepath))
          extract(entry, filepath)
        end
      end

      @epubdir
    end

    private

    # Returns the path +entry+ is to be extracted to, or raises Epzip::Error if
    # it must not be extracted.
    def target_path(entry)
      filepath = File.expand_path(File.join(@root, entry.name))
      # Guard against Zip Slip: reject entries that would escape the target
      # directory instead of relying on rubyzip, which either skips its own
      # check (2.x, explicit destination path) or only warns (3.x).
      unless filepath.start_with?(@root + File::SEPARATOR)
        raise Error, "Illegal entry name -- #{entry.name}"
      end

      # The check above only looks at the path as a string. A symbolic link
      # below the target directory could still lead the write elsewhere.
      path = filepath
      until path == @root
        if File.symlink?(path)
          raise Error, "Symbolic link in the target directory -- #{path}"
        end

        path = File.dirname(path)
      end

      if !@overwrite && File.exist?(filepath)
        raise Error, "File already exists -- #{filepath}"
      end

      filepath
    end

    # The block tells rubyzip whether it may replace an existing file.
    def extract(entry, filepath)
      if RUBYZIP_V3_EXTRACT
        entry.extract(entry.name, destination_directory: @root) { @overwrite }
      else
        entry.extract(filepath) { @overwrite }
      end
    end
  end
  private_constant :Unpacker
end
