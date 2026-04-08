# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- This changelog.

### Fixed

- Resolved ShellCheck warnings in library and handler scripts: unused configuration and handler parameters, and a false positive for `output_root` in `doctor/checks.sh` after `config_load()`.
- Continuous integration ShellCheck invocation for entrypoint scripts: `source=` paths that use `..` are resolved relative to the process working directory unless a search path is provided, which caused failures when linting from the repository root on newer ShellCheck releases.

### Changed

- `config_print` now includes `log_level` in its output so the resolved configuration dump matches the full default set loaded by `config_load()`.
- GitHub Actions runs ShellCheck with `-P` and `-x` for `bin/ripperoni` and `doctor/checks.sh`, and restricts the bulk `find` pass to `lib/**/*.sh` so `doctor/checks.sh` is not analyzed twice under incompatible options.
