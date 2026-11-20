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
    # File::ALT_SEPARATOR is the backslash on Windows, and nil elsewhere.
    TRAILING_SEPARATORS = /[#{Regexp.escape([File::SEPARATOR, File::ALT_SEPARATOR].join)}]+\z/

    def initialize(epubdir, epubfile)
      unless File.directory?(epubdir)
        raise ArgumentError, "No such directory -- #{epubdir}"
      end

      @epubdir = epubdir
      # "book/" must become "book.epub", not "book/.epub".
      @epubfile = epubfile || epubdir.to_s.sub(TRAILING_SEPARATORS, "") + ".epub"
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
      # Only a root directory ends with a separator.
      prefix = root.end_with?(File::SEPARATOR) ? root : root + File::SEPARATOR
      # An EPUB left in the source directory by an earlier run is about to be
      # replaced, so it cannot be packed into itself.
      output = File.realpath(@epubfile) if File.exist?(@epubfile)

      Dir.glob("**/*", base: @epubdir).select do |path|
        next false if path == MIMETYPE_FILENAME

        file = File.join(@epubdir, path)
        # File.file? follows symbolic links, and so would reading the file.
        next false unless File.file?(file)

        realpath = File.realpath(file)
        unless realpath.start_with?(prefix)
          raise Error, "Symbolic link to outside of the source directory -- #{path}"
        end

        realpath != output
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
      # Only a root directory ends with a separator.
      @prefix = @root.end_with?(File::SEPARATOR) ? @root : @root + File::SEPARATOR
      @overwrite = overwrite
    end

    def unpack
      Zip::File.open(@epubfile) do |zip|
        check_root
        # A directory entry usually ends with a separator, but may also be
        # marked as a directory by its attributes alone.
        files = zip.reject { |entry| entry.name_is_directory? || entry.directory? }
        targets = files.map { |entry| [entry, target_path(entry)] }
        check_conflicts(targets)

        # Create the target only once the archive has been opened and checked,
        # so that a rejected file does not leave an empty directory behind.
        FileUtils.mkdir_p(@root)
        targets.each do |entry, filepath|
          FileUtils.mkdir_p(File.dirname(filepath))
          extract(entry, filepath)
        end
      end

      @epubdir
    end

    private

    # Raises Epzip::Error if the target directory cannot be created or used,
    # because something else (or a dangling symbolic link) has its name or
    # the name of one of the directories leading to it.
    def check_root
      # The target directory itself, or the closest thing that exists above it.
      path = @root
      until File.exist?(path) || File.symlink?(path)
        parent = File.dirname(path)
        break if parent == path

        path = parent
      end
      return if File.directory?(path)

      raise Error, "Not a directory -- #{path}"
    end

    # Returns the path +entry+ is to be extracted to, or raises Epzip::Error if
    # it must not be extracted.
    def target_path(entry)
      # rubyzip returns the name as a binary string, which cannot be joined to
      # a target directory with non-ASCII characters in its path.
      name = entry.name.dup.force_encoding(@root.encoding)
      filepath = begin
        File.expand_path(File.join(@root, name))
      rescue ArgumentError # a null byte in the name
        raise Error, "Illegal entry name -- #{entry.name.inspect}"
      end
      # Guard against Zip Slip: reject entries that would escape the target
      # directory instead of relying on rubyzip, which either skips its own
      # check (2.x, explicit destination path) or only warns (3.x).
      unless filepath.start_with?(@prefix)
        raise Error, "Illegal entry name -- #{entry.name}"
      end

      # The check above only looks at the path as a string. A symbolic link
      # below the target directory could still lead the write elsewhere.
      path = filepath
      until path == @root
        if File.symlink?(path)
          raise Error, "Symbolic link in the target directory -- #{path}"
        end
        # A directory is needed here, and a file cannot be replaced by one.
        if path != filepath && File.exist?(path) && !File.directory?(path)
          raise Error, "Not a directory -- #{path}"
        end

        path = File.dirname(path)
      end

      # A directory cannot be replaced by a file, even when overwriting.
      if File.directory?(filepath)
        raise Error, "Directory already exists -- #{filepath}"
      elsif File.exist?(filepath)
        raise Error, "File already exists -- #{filepath}" unless @overwrite
        # Writing to a named pipe or a device would not replace it.
        raise Error, "Not a regular file -- #{filepath}" unless File.file?(filepath)
      end

      filepath
    end

    # Raises Epzip::Error if the entries cannot all be extracted: two of them
    # go to the same path, or one is a file where another needs a directory.
    # Such an archive would otherwise fail halfway through the extraction.
    def check_conflicts(targets)
      entries = {}
      targets.each do |entry, filepath|
        if entries.key?(filepath)
          raise Error, "Duplicate entry -- #{entry.name}"
        end

        entries[filepath] = entry
      end

      targets.each do |_entry, filepath|
        dir = File.dirname(filepath)
        until dir == @root
          if entries.key?(dir)
            raise Error, "Entry is both a file and a directory -- #{entries[dir].name}"
          end

          dir = File.dirname(dir)
        end
      end
    end

    # The block tells rubyzip whether it may replace an existing file.
    def extract(entry, filepath)
      if RUBYZIP_V3_EXTRACT
        # The checked path, relative to the target directory, and not the
        # binary entry name: rubyzip joins it to the directory again.
        relative = filepath.delete_prefix(@prefix)
        entry.extract(relative, destination_directory: @root) { @overwrite }
      else
        entry.extract(filepath) { @overwrite }
      end
    end
  end
  private_constant :Unpacker
end
