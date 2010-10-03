require 'rubygems'
require 'zip/zip'

class Epzip
  MIMETYPE_FILENAME = 'mimetype'
  
  def self.zip(epubdir, epubfile = nil)
    if !File.exists? epubdir
      raise ArgumentError, "No such directory -- #{epubdir}"
    end

    epubfile ||= epubdir+".epub"

    Zip::ZipOutputStream.open(epubfile) do |f|

      f.put_next_entry(MIMETYPE_FILENAME, nil, nil, Zip::ZipEntry::STORED)
      f << "application/epub+zip"
      puts MIMETYPE_FILENAME

      Dir.chdir(epubdir) do
        Dir.glob("**/*") do |dir|
          next if dir == MIMETYPE_FILENAME
          next if !File.file? dir
          puts dir
          f.put_next_entry dir
          f << File.read(dir)
        end
      end
    end

    epubfile
    
  end

  def self.unzip(epubfile, epubdir = nil)
    if epubdir
      FileUtils.mkdir_p(epubdir)
    else
      epubdir = Dir.pwd
    end

    Zip::ZipInputStream.open(epubfile) do |f|
      while entry = f.get_next_entry
        next if entry.directory?
        next if entry.name[-1] == "/"
        sep = "/"
        if entry.name[0] == "/"
          sep = ""
        end
        filepath = epubdir + sep + entry.name
        dir = File.dirname(filepath)
        FileUtils.mkdir_p(dir)
        entry.extract(filepath)
      end
    end

  end

end
