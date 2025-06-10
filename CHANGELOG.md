# Changelog for detox.sh

All notable changes to this project will be documented in this file.

---

## [1.3.5] - 2025-05-26

### Added in 1.3.5

- `log_cleaned()` function to display the current cleaning result below the progress bar.
- Deferred logging system for debug output and Perl errors during cleaning.
- Displays `[CLEAN]` line for each processed file with color.
- Captures line-diff stats from Perl cleaning via `diff -U 0`.

### Changed in 1.3.5

- All Perl execution now uses `2>perl_err.log` to capture stderr.
- Fatal Perl failures are now logged clearly and do not crash the run.
- Progress bar remains clean and stable during verbose operation.

### Fixed in 1.3.5

- Prevented line wrapping and clutter during progress display.
- Correct logging behavior in dry-run mode and with `--quiet`.

### Removed in 1.3.5

- Redundant direct debug prints during cleaning phase (replaced with deferred logs).

## [1.3.4] - 2025-05-26

### Fixed in 1.3.4

- Removed use of `-CS` and `-Mopen=:utf8` from Perl calls to avoid UTF-8 decoding crashes on malformed input
- Added trap handling for Perl substitution failures
- Logs a `[SKIP]` warning if Perl fails to process a given file

### Changed in 1.3.4

- `clean_file()` now runs Perl substitution in byte mode only, increasing compatibility with raw or corrupted text

## [1.3.3] - 2025-05-26

### Changed in 1.3.3

- Cleaned files are now processed in-place; removed `--output` and `--purge` logic.
- All cleaning results are logged to `input_dir/clean.log` only if not in dry-run.
- Logic restructured to prevent premature cleanup log creation during dry runs.
- Fixed Perl encoding and UTF-8 handling issues for zero-width characters and BOMs.
- Improved trap handling with corrected quoting.
- Removed silent failure due to `((var++))` in `set -e` mode.
- Perl invocation uses `-Mopen=:utf8` for robust multi-byte character handling.
- Removed config override test logic from `detox.test.sh`.

## [1.3.2] - 2025-05-26

### Fixed in 1.3.2

- Bug where `((cleaned++))` would crash due to unset variable under `set -euo pipefail`.
- Added guards and explicit return values to `clean_file()` to prevent silent exit.

## [1.3.1] - 2025-05-26

### Fixed in 1.3.1

- Missing file write caused failure to continue processing input files.
- Progress bar now renders correctly through refactored control flow.

## [1.3.0] - 2025-05-25

### Changed in 1.3.0

- Major refactor to eliminate output directory.
- All files are now cleaned in-place and `--output`/`--purge` flags removed.
- Logging updated to reflect in-place workflow.

## [1.2.6] - 2025-05-25

### Changed in 1.2.6

- `detox.test.sh` refactored for trap-based cleanup and structured test lifecycle.
- Switched logging to config-driven helpers.
- Validates results directly against `test_dir`, not an output directory.
- Supports full version flag parsing and exits.

## [1.2.5] - 2025-05-25

### Changed in 1.2.5

- Switched all short-circuit syntax to full `if [[ ... ]]; then ... fi` blocks.
- Brings `detox.sh` in full compliance with Canonical Bash Code Style.

## [1.2.4] - 2025-05-25

### Fixed in 1.2.4

- Copy logic for clean-but-unchanged files now always triggers unless in dry-run.
- Added debug logs to clarify file copy actions.

## [1.2.3] - 2025-05-25

### Fixed in 1.2.3

- Refactored `run_cleaning()` to declare `file` as a local inside loop to prevent variable leakage.

---
