#!/usr/bin/env bash

# ============================================================================
#  detox.test.sh
#  Automated test suite for detox.sh
#
#  Author: Blake Simpson
#  License: MIT
#  Version: 1.2.6
#  Usage: ./detox.test.sh
# ============================================================================

# shellcheck disable=SC1090
set -euo pipefail
IFS=$'\n\t'

if [[ "${1:-}" == "--version" || "${1:-}" == "-v" ]]; then
  cat "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/VERSION"
  exit 0
fi

test_dir="./testdata"
test_failed=false

# ----------------------------------------------------------------------------
# load_config(): Load detox.conf for color variables
# Globals:
#   CONFIG_FILE
# Outputs:
#   Sources detox.conf into environment
# ----------------------------------------------------------------------------
load_config() {
  CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/detox.conf"
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
  else
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    BLUE="\033[0;34m"
    RESET="\033[0m"
  fi
}

# ----------------------------------------------------------------------------
# log_info(), log_warn(), log_error(), log_success(): Logging helpers
# ----------------------------------------------------------------------------
log_info() { echo -e "${BLUE}[INFO] $1${RESET}"; }
log_warn() { echo -e "${YELLOW}[SKIP] $1${RESET}"; }
log_error() { echo -e "${RED}[FAIL] $1${RESET}" >&2; }
log_success() { echo -e "${GREEN}[OK] $1${RESET}"; }

# ----------------------------------------------------------------------------
# cleanup(): Removes test artifacts and restores permissions
# Globals:
#   test_dir
# Arguments:
#   None
# Outputs:
#   Deletes test dir and resets unreadable.txt
# ----------------------------------------------------------------------------
cleanup() {
  log_info "Cleaning up test environment..."
  rm -rf "$test_dir"

  if [[ -e "$test_dir/unreadable.txt" ]]; then
    chmod 644 "$test_dir/unreadable.txt" || true
  fi

  log_success "Cleanup complete."
}

# ----------------------------------------------------------------------------
# prompt_cleanup_on_failure(): Prompts user to cleanup if test fails
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Asks user whether to run cleanup()
# ----------------------------------------------------------------------------
prompt_cleanup_on_failure() {
  echo
  read -rp "Tests failed. Do you want to clean up test artifacts? [Y/N] " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    cleanup
  else
    log_warn "Skipped cleanup — artifacts remain for inspection."
  fi
}

# ----------------------------------------------------------------------------
# on_test_exit(): Cleanup logic on script exit
# Globals:
#   test_failed
# Arguments:
#   None
# Outputs:
#   Conditionally runs cleanup or prompts user
# ----------------------------------------------------------------------------
on_test_exit() {
  if [[ "$test_failed" == true ]]; then
    prompt_cleanup_on_failure
  else
    cleanup
  fi
}

trap on_test_exit EXIT

# ----------------------------------------------------------------------------
# setup_environment(): Prepare files for testing
# Globals:
#   test_dir
# Arguments:
#   None
# Outputs:
#   Creates sample input files and directories
# ----------------------------------------------------------------------------
setup_environment() {
  if [[ -d "$test_dir" ]]; then
    cleanup
  fi

  mkdir -p "$test_dir"

  printf "Hello\x00World\nLine2" >"$test_dir/binary.txt"
  printf "Text​withZWCPadding\xEF\xBB\xBF\nOK" >"$test_dir/zwc.txt"
  echo "Just a normal text file." >"$test_dir/clean.txt"
  touch "$test_dir/unreadable.txt"
  chmod 000 "$test_dir/unreadable.txt"
}

# ----------------------------------------------------------------------------
# test_cleaning(): Tests actual cleaning behavior
# Globals:
#   test_dir, test_failed
# Arguments:
#   None
# Outputs:
#   Asserts proper file cleaning and logging
# ----------------------------------------------------------------------------
test_cleaning() {
  log_info "Running detox in normal mode..."
  bash detox.sh -i "$test_dir" -y -d

  log_info "Asserting cleaning results..."

  if grep -P '\x00' "$test_dir/binary.txt"; then
    log_error "binary.txt contains null byte after cleaning"
    test_failed=true
    return 1
  fi

  if grep -P '\x{200B}|\xEF\xBB\xBF' "$test_dir/zwc.txt"; then
    log_error "zwc.txt contains zero-width or BOM after cleaning"
    test_failed=true
    return 1
  fi

  if [[ ! -s "$test_dir/clean.log" ]]; then
    log_error "clean.log was not created or is empty"
    test_failed=true
    return 1
  fi

  log_success "Cleaning test passed"
}

# ----------------------------------------------------------------------------
# test_dry_run(): Tests --dry-run behavior
# Globals:
#   test_dir, test_failed
# Arguments:
#   None
# Outputs:
#   Ensures dry run makes no changes
# ----------------------------------------------------------------------------
test_dry_run() {
  log_info "Running detox in dry-run mode..."
  bash detox.sh -i "$test_dir" -n -y --quiet

  log_info "Asserting dry-run outcomes..."

  if [[ -f "$test_dir/clean.log" ]]; then
    log_error "clean.log should not exist in dry-run"
    test_failed=true
    return 1
  fi

  log_success "Dry-run test passed"
}

# ----------------------------------------------------------------------------
# main(): Entry point for test execution
# Globals:
#   All
# Arguments:
#   None
# Outputs:
#   Runs full test suite
# ----------------------------------------------------------------------------
main() {
  load_config
  setup_environment
  test_cleaning
  cleanup
  setup_environment
  test_dry_run
  cleanup
  setup_environment
  log_success "All tests passed."
}

main "$@"
