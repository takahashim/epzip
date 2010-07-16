require 'rubygems'
require 'zip/zip'

class Epzip
  def self.zip(epubdir, epubfile = nil)
    if !File.exists? epubdir
      raise ArgumentError, "No such directory -- #{epubdir}"
    end

    if !epubfile
      epubfile = epubdir+".epub"
    end

    MIMETYPE_FILENAME = 'mimetype'

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

    return epubfile
    
  end
end
