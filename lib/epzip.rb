require 'fileutils'
require 'tmpdir'
class Epzip
  MIMETYPE_FILENAME = 'mimetype'

  @@zip_cmd_path = 'zip'
  @@unzip_cmd_path = 'unzip'
  
  def self.zip_cmd_path=(cmd); @@zip_cmd_path = cmd end
  def self.zip_cmd_path;       @@zip_cmd_path end
  def self.unzip_cmd_path=(cmd); @@unzip_cmd_path = cmd end
  def self.unzip_cmd_path;       @@unzip_cmd_path end
  
  def self.zip(epubdir, epubfile = nil)
    if !File.exists? epubdir
      raise ArgumentError, "No such directory -- #{epubdir}"
    end

    epubfile ||= epubdir+".epub"
    
    Dir.mktmpdir do |tmpdir|
      tmpfile = "#{tmpdir}/tmp.epub"

      Dir.chdir(epubdir) do
        File.open(MIMETYPE_FILENAME, "w") do |f|
          f.write("application/epub+zip")
        end
        system("#{@@zip_cmd_path} -0X #{tmpfile} #{MIMETYPE_FILENAME}")
        system("#{@@zip_cmd_path} -Xr9D #{tmpfile} * -x #{MIMETYPE_FILENAME}")
      end

      FileUtils.cp(tmpfile, epubfile)
    end
    epubfile
  end

  def self.unzip(epubfile, epubdir = nil)
    if epubdir
      FileUtils.mkdir_p(epubdir)
    else
      epubdir = Dir.pwd
    end

    system("#{@@unzip_cmd_path} #{epubfile} -d #{epubdir}")
  end

end
