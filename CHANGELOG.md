# Changelog

## 0.10.0 - Unreleased

- Support rubyzip 3.x in addition to 2.x (rubyzip 2.3 or later is now required).
- Never write an extra field on the `mimetype` entry. With rubyzip 3.x a Zip64
  extra field was added, which EPUB (OCF) does not allow.
- Require Ruby 3.0 or later.
- Raise `Epzip::Error` instead of `ArgumentError` for archive entries that
  would extract outside the target directory.
- `Epzip.unzip` and `epunzip` no longer overwrite existing files. Pass
  `overwrite: true` to `Epzip.unzip` to replace them.
- `Epzip.unzip` and `epunzip` refuse to extract through a symbolic link that
  already exists in the target directory.
- `Epzip.unzip` and `epunzip` check every entry before extracting, so a
  rejected archive leaves nothing behind.
- `Epzip.zip` and `epzip` refuse a symbolic link to a file outside the source
  directory. Links to files inside it are still followed.
- `Epzip.unzip` and `epunzip` also reject, before extracting, an archive whose
  entries conflict with each other (a name used as both a file and a
  directory) or with a file or directory that already exists in the target.
- `Epzip.zip` no longer changes the current directory of the process, and
  raises `ArgumentError` when the source is not a directory.
- `Epzip.zip` and `epzip` name the default output `book.epub` for the source
  `book/` (it was `book/.epub`), and do not pack an output file left in the
  source directory by an earlier run into itself.
- Print an error message instead of a backtrace when the command-line tools
  hit an invalid archive.
- Do not leave an empty target directory behind when the archive cannot be
  opened.
- Move the executables from `bin/` to `exe/`, and stop shipping tests and CI
  settings in the gem.
- Convert README to Markdown.

## 0.9.0 - 2026-07-04

- Support current Ruby and rubyzip versions.
- Reject archive entries that would extract outside the target directory.
- Exit with a non-zero status when the command-line tools fail.
