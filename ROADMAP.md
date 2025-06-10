# Detox.sh Roadmap

This document outlines the proposed evolution of `detox.sh` for performance, feature maturity, and maintainability. All ideas align with canonical version `v1.3.5`.

---

## 🏎️ Performance Enhancements

### 1. Avoid `cmp` for File Change Detection

* Replace `cmp` with faster hash comparison (e.g. `md5sum`) or checksum-based logic
* Or: restructure Perl regex to return an exit code when matches are made

### 2. Stream-Based Cleaning

* Avoid Perl loading entire file into memory
* Use line-at-a-time or streaming substitution mode to reduce memory pressure

### 3. Parallel Processing

* Add `--jobs N` option
* Use `xargs -P` or custom job queue to process files in parallel
* Maintain compatibility with quiet/debug/progress bar display

### 4. Reduce Tempfile Overhead

* Replace `mktemp` per file with a fixed `.tmp` location per cleaning session
* Consider safe in-place `perl -i` editing if we ensure backup fallback

---

## 🚀 Future Improvements

### 1. Regex Precompilation

* Evaluate compiling regex into a module or eval block reused across executions

### 2. Interactive Diff Preview

* Add `--preview` flag in interactive mode to show unified diff via `diff -u` and `less`

### 3. Cross-Platform Enhancements

* Audit for GNU-only commands (`grep -P`, `seq`, etc.)
* Fallbacks for `sed`/`awk` if Perl is unavailable

### 4. Structured Logging

* Add `--log-json` flag to output structured logs for CI consumption
* Include file name, status, changes, error info if any

### 5. File Type Filtering

* Support `--ext=md,csv,txt` for extension-based file filtering
* Default remains `.txt` if not specified

---

## 🧠 Strategic & Miscellaneous

### 1. Plugin Support

* Hook-based cleaning extensibility
* Example: allow user-defined filters for `.md` or `.csv`

### 2. Safe Mode

* `--backup` flag to copy original file to `.bak` before replacing
* Guardrail for first-time adoption or fragile downstream consumers

### 3. Benchmark Mode

* Add `--benchmark` to measure:

  * File size before/after
  * Time per file
  * Total time

### 4. CI Enforcement Mode

* `--fail-on-dirty` to exit with non-zero if any files require cleaning
* Integrates into pre-commit or CI pipelines

---

## 🔄 Candidate for Next Release: v1.4.0

* [ ] Add file extension filtering (`--ext`)
* [ ] Implement safe mode with `.bak` backups
* [ ] Optimize `cmp` usage via `diff` or content hash
* [ ] Suppress all logs during clean; show summary after
* [ ] Optional benchmark stats

---

*Last updated: May 26, 2025*
