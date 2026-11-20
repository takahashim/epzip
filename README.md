# epzip

epzip (and epunzip) is an EPUB packing tool. It's just only doing 'zip' and 'unzip'. :)

## Installation

```console
$ gem install epzip
```

epzip requires Ruby 3.0 or later.

## Usage

```console
$ epzip <srcdir> [filename]
```

`srcdir` is the EPUB resource directory; it has mimetype, META-INF/container.xml,
and other assets.

`filename` is the EPUB filename that will be created. If no filename is given,
`srcdir` + ".epub" is used.

```console
$ epunzip <filename> [targetdir]
```

`filename` is the EPUB filename that will be extracted.

`targetdir` is the EPUB resource directory to be extracted into. If no targetdir
is given, the current directory is used.

You can also use it as a library:

```ruby
require 'epzip'

Epzip.zip("book", "book.epub")
Epzip.unzip("book.epub", "book")
Epzip.unzip("book.epub", "book", overwrite: true) # replace existing files
```

## Handling files from someone else

epzip and epunzip stop with an error, without writing anything, when:

* `srcdir` contains a symbolic link to a file outside of it (epzip).
* an entry would be extracted outside of `targetdir`, through a symbolic link
  that already exists in it, or over an existing file (epunzip).

epunzip does not limit the size or the number of the extracted files. If you
extract EPUB files that you cannot trust, check them first; for example, sum
up `Zip::Entry#size` of the entries with rubyzip.

## Development

```console
$ bundle install
$ bundle exec rake test
```

## Note on Patches/Pull Requests

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2010 Masayoshi Takahashi. See LICENSE for details.
