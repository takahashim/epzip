# Changelog

## 0.10.0 - Unreleased

- Support rubyzip 3.x in addition to 2.x (rubyzip 2.3 or later is now required).
- Never write an extra field on the `mimetype` entry. With rubyzip 3.x a Zip64
  extra field was added, which EPUB (OCF) does not allow.
- Require Ruby 3.0 or later.
- Raise `Epzip::Error` instead of `ArgumentError` for archive entries that
  would extract outside the target directory.
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
