#!/usr/bin/env bash

# ============================================================================
#  detox.sh
#  Remove binary and zero-width characters from text files
#
#  Author: Blake Simpson
#  License: MIT
#  Version: 1.3.6
#  Usage: See README.md or run with --help for details
#  Disclaimer: Use with caution. Backup your files before cleaning.
# ============================================================================

# shellcheck disable=SC2064
# shellcheck disable=SC1090
# shellcheck disable=SC2154
set -euo pipefail
IFS=$'\n\t'

# ----------------------------------------------------------------------------
# load_config(): Load configuration from detox.conf
# Globals:
#   CONFIG_FILE
# Outputs:
#   Sources variables from detox.conf or fails if missing
# ----------------------------------------------------------------------------
load_config() {
  CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/detox.conf"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[FAIL] Configuration file not found: $CONFIG_FILE" >&2
    exit 1
  fi
  source "$CONFIG_FILE"
}

# ----------------------------------------------------------------------------
# log_info(): Display an informational message
# Globals:
#   BLUE, RESET
# Arguments:
#   $1 - Message to display
# Outputs:
#   Writes to stdout
# ----------------------------------------------------------------------------
log_info() {
  echo -e "${BLUE}[INFO] $1${RESET}"
}

# ----------------------------------------------------------------------------
# log_warn(): Display a warning message
# Globals:
#   YELLOW, RESET
# Arguments:
#   $1 - Message to display
# Outputs:
#   Writes to stdout
# ----------------------------------------------------------------------------
log_warn() {
  echo -e "${YELLOW}[SKIP] $1${RESET}"
}

# ----------------------------------------------------------------------------
# log_error(): Display an error message
# Globals:
#   RED, RESET
# Arguments:
#   $1 - Message to display
# Outputs:
#   Writes to stderr
# ----------------------------------------------------------------------------
log_error() {
  echo -e "${RED}[FAIL] $1${RESET}" >&2
}

# ----------------------------------------------------------------------------
# log_success(): Display a success message
# Globals:
#   GREEN, RESET
# Arguments:
#   $1 - Message to display
# Outputs:
#   Writes to stdout
# ----------------------------------------------------------------------------
log_success() {
  echo -e "${GREEN}[OK] $1${RESET}"
}

# ----------------------------------------------------------------------------
# log_cleaned(): Store most recent cleaning message
# Globals:
#   CLEAN, RESET, last_cleaned_message
# Arguments:
#   $1 - Cleaning summary
# Outputs:
#   Sets last_cleaned_message for display
# ----------------------------------------------------------------------------
log_cleaned() {
  last_cleaned_message="${CLEAN}[CLEAN] $1${RESET}"
}

# ----------------------------------------------------------------------------
# check_dependencies(): Ensures required tools are installed
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Exits if Perl is not installed
# ----------------------------------------------------------------------------
check_dependencies() {
  if ! command -v perl &>/dev/null; then
    log_error "Perl is required but not installed."
    exit 1
  fi
}

# ----------------------------------------------------------------------------
# init_flags(): Initialize default flag values
# Globals:
#   ignore_zwc, dry_run, debug, auto_confirm, quiet, deferred_logs,
#   last_cleaned_message
# Arguments:
#   None
# Outputs:
#   Sets global default values
# ----------------------------------------------------------------------------
init_flags() {
  ignore_zwc=false
  dry_run=false
  debug=false
  auto_confirm=false
  quiet=false
  deferred_logs=()
  last_cleaned_message="Scanning..."
}

# ----------------------------------------------------------------------------
# usage(): Displays usage information and exits
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Usage guide
# ----------------------------------------------------------------------------
usage() {
  cat <<EOF

Usage: $0 [OPTIONS]

Options:
  -i, --input <dir>         Input directory containing .txt files
  -n, --dry-run             Show what would be cleaned
  -d, --debug               Enable verbose debug output
  -y, --yes                 Skip confirmation prompt
  --ignore-zwc              Skip zero-width character cleaning
  --quiet                   Suppress progress indicators and summary
  -h, --help                Show this help message and exit
  -v, --version             Show detox version and exit

EOF
  exit 0
}

# ----------------------------------------------------------------------------
# parse_args(): Parses and validates command-line arguments
# Globals:
#   input_dir, dry_run, debug, auto_confirm, ignore_zwc, quiet
# Arguments:
#   $@ - CLI arguments
# Outputs:
#   Populates global flags
# ----------------------------------------------------------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i | --input)
        input_dir="$2"
        shift 2
        ;;
      -n | --dry-run)
        dry_run=true
        shift
        ;;
      -d | --debug)
        debug=true
        shift
        ;;
      -y | --yes)
        auto_confirm=true
        shift
        ;;
      --ignore-zwc)
        ignore_zwc=true
        shift
        ;;
      --quiet)
        quiet=true
        shift
        ;;
      -h | --help) usage ;;
      -v | --version)
        cat "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/VERSION"
        exit 0
        ;;
      *)
        log_warn "Unknown option: $1"
        usage
        ;;
    esac
  done

  input_dir="${input_dir:-./data}"
}

# ----------------------------------------------------------------------------
# show_progress(): Display a progress bar
# Globals:
#   quiet
# Arguments:
#   $1 - current index
#   $2 - total files
# Outputs:
#   Single-line percentage + bar display
# ----------------------------------------------------------------------------
show_progress() {
  if [[ "$quiet" == true ]]; then return; fi
  local cur=$1 total=$2 width=30 pct filled empty

  pct=$((cur * 100 / total))
  filled=$((cur * width / total))
  empty=$((width - filled))

  ((filled < 0)) && filled=0
  ((filled > width)) && filled=width
  ((empty < 0)) && empty=0
  ((empty > width)) && empty=width

  local hashes="" dashes=""
  for ((i = 0; i < filled; i++)); do hashes+="#"; done
  for ((i = 0; i < empty; i++)); do dashes+="-"; done

  printf "\r[%s%s] %3d%% (%d/%d)" \
    "$hashes" "$dashes" "$pct" "$cur" "$total"
}

# ----------------------------------------------------------------------------
# handle_progress(): Redraw both progress bar and latest log line
# Globals:
#   quiet, last_cleaned_message
# Arguments:
#   $1 - current index
#   $2 - total files
# Outputs:
#   Redraws bar and status underneath
# ----------------------------------------------------------------------------
handle_progress() {
  if [[ "$quiet" == true ]]; then return; fi

  tput cuu1 2>/dev/null || printf "\033[A"
  tput el 2>/dev/null || printf "\033[2K"
  tput cuu1 2>/dev/null || printf "\033[A"
  tput el 2>/dev/null || printf "\033[2K"

  show_progress "$@"
  echo
  echo -e "$last_cleaned_message"
}

# ----------------------------------------------------------------------------
# clean_file(): In-place clean of binary/ZWC chars via Perl
# Globals:
#   input_dir, dry_run, debug, auto_confirm, ignore_zwc,
#   PERL_BINARY_REGEX, PERL_COMBINED_REGEX, deferred_logs
# Arguments:
#   $1 - file path
# Outputs:
#   Writes cleaned file in place or logs if unchanged
# ----------------------------------------------------------------------------
clean_file() {
  local file="$1"
  local tmp changes
  tmp=$(mktemp)
  trap "rm -f $tmp" RETURN

  if [[ "$ignore_zwc" == true ]]; then
    perl -CS -Mopen=IN,:bytes,OUT,:bytes -pe \
      "$PERL_BINARY_REGEX" "$file" >"$tmp" 2>perl_err.log || {
      deferred_logs+=("${RED}[PERL FAIL] $file: $(<perl_err.log)${RESET}")
      return 1
    }
  else
    perl -CS -Mopen=IN,:bytes,OUT,:bytes -pe \
      "$PERL_COMBINED_REGEX" "$file" >"$tmp" 2>perl_err.log || {
      deferred_logs+=("${RED}[PERL FAIL] $file: $(<perl_err.log)${RESET}")
      return 1
    }
  fi

  if [[ "$dry_run" == true ]]; then
    log_cleaned "[DRY-RUN] Would clean: $file"
    return 0
  fi

  if cmp -s "$file" "$tmp"; then
    log_cleaned "Already clean: $file"
    return 0
  fi

  if [[ "$auto_confirm" != true ]]; then
    read -rp "Clean $file? [Y/N] " ans
    [[ ! "$ans" =~ ^[Yy]$ ]] && return 0
  fi

  mv "$tmp" "$file"
  log_cleaned "Cleaned in-place: $file"

  if [[ "$debug" == true ]]; then
    changes=$(diff -U 0 "$file" "$tmp" | grep -c '^[-+]' || true)
    deferred_logs+=("${BLUE}[DEBUG] Changes in $file: ~$changes lines modified${RESET}")
  fi

  echo "$file" >>"$input_dir/clean.log"
  return 0
}

# ----------------------------------------------------------------------------
# run_cleaning(): Scans and applies cleaning to input directory
# Globals:
#   input_dir, dry_run, debug, quiet, deferred_logs
# Arguments:
#   None
# Outputs:
#   Runs clean on all .txt files
# ----------------------------------------------------------------------------
run_cleaning() {
  log_info "Scanning for text files..."
  if [[ "$dry_run" != true ]]; then
    echo "# Clean log - $(date)" >"$input_dir/clean.log"
  fi

  mapfile -t files < <(find "$input_dir" -type f -name '*.txt')
  local total=${#files[@]} cleaned=0 skipped=0

  echo "Found $total file(s) to process in '$input_dir'."

  for idx in "${!files[@]}"; do
    local file=${files[idx]}
    ((i = idx + 1))

    if [[ ! -r $file ]]; then
      log_warn "Unreadable file skipped: $file"
      skipped=$((skipped + 1))
      continue
    fi

    if clean_file "$file"; then
      cleaned=$((cleaned + 1))
    fi

    handle_progress "$i" "$total"
  done

  if [[ "$quiet" != true ]]; then echo; fi
  log_success "Detox complete. $cleaned file(s) cleaned. $skipped skipped."

  if [[ "$dry_run" != true ]]; then
    log_info "Log saved to $input_dir/clean.log"
  fi

  if [[ ${#deferred_logs[@]} -gt 0 ]]; then
    echo
    for log in "${deferred_logs[@]}"; do
      echo -e "$log"
    done
  fi
}

# ----------------------------------------------------------------------------
# main(): Entry point for execution
# Globals:
#   All
# Arguments:
#   CLI args
# Outputs:
#   Calls cleaning pipeline
# ----------------------------------------------------------------------------
main() {
  load_config
  check_dependencies
  init_flags
  parse_args "$@"
  run_cleaning
}

main "$@"
