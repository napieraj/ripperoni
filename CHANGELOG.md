# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Optional macOS helper `ripperoni-iokit-state` ([tools/macos-iokit-state/](tools/macos-iokit-state/)): IOKit-based drive state (`open`, `empty`, `loading`, `ready`, `busy`) with `drutil` fallback; `RIPPERONI_IOKIT_STATE` override; wiretap `source` reflects `iokit` vs `drutil`. CI builds the helper on `macos-latest`.
- This changelog.

### Fixed

- `ripperoni wiretap` on macOS: JSON `source` was always `drutil` because `$(state_read …)` ran in a subshell and discarded `RIPPERONI_STATE_SOURCE`. `state_wiretap` now uses `_state_read_dispatch` in the current shell so `iokit` vs `drutil` is accurate when the IOKit helper is in use (`lib/state.sh`).
- Resolved ShellCheck warnings in library and handler scripts: unused configuration and handler parameters, and a false positive for `output_root` in `doctor/checks.sh` after `config_load()`.
- Continuous integration ShellCheck invocation for entrypoint scripts: `source=` paths that use `..` are resolved relative to the process working directory unless a search path is provided, which caused failures when linting from the repository root on newer ShellCheck releases.
- `lib/drive.sh` Linux sysfs reads: replaced `cat … | tr` with `tr` redirection (SC2002) and explicit `-r` tests so missing nodes stay quiet, matching prior behavior on Ubuntu CI’s ShellCheck 0.9.x.

### Changed

- `config_print` now includes `log_level` in its output so the resolved configuration dump matches the full default set loaded by `config_load()`.
- GitHub Actions runs ShellCheck with `-P` and `-x` for `bin/ripperoni` and `doctor/checks.sh`, and restricts the bulk `find` pass to `lib/**/*.sh` so `doctor/checks.sh` is not analyzed twice under incompatible options.
