#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  batch_runner.sh
#  Run a script on each subdirectory, renaming folders after processing.
#
#  Author: Blake Simpson
#  License: MIT
#  Version: 1.2.0
#  Usage: ./batch_runner.sh <parent_dir> <script_to_run> <old> <new> [-- args]
#
#  Example:
#    ./batch_runner.sh ./datasets ./process.sh _raw _done
#    ./batch_runner.sh ./datasets ./process.sh _tmp _final -- --mode strict
# ----------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# ----------------------------------------------------------------------------
# check_dependencies(): Ensure required commands are available
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Error if commands are missing
# ----------------------------------------------------------------------------
check_dependencies() {
  command -v bash >/dev/null || {
    echo "[ERROR] bash is required but not found." >&2
    exit 1
  }
}

# ----------------------------------------------------------------------------
# rename_folder(): Rename folder by replacing a substring in its name
# Globals:
#   None
# Arguments:
#   $1 - full path to folder
#   $2 - string to replace
#   $3 - replacement string
# Outputs:
#   Renames folder
# ----------------------------------------------------------------------------
rename_folder() {
  local folder_path=$1
  local from=$2
  local to=$3

  local base_name
  base_name=$(basename "$folder_path")
  local parent_dir
  parent_dir=$(dirname "$folder_path")
  local new_base_name
  new_base_name=${base_name//$from/$to}

  if [[ "$base_name" == "$new_base_name" ]]; then
    echo "[INFO] No rename needed for: $base_name"
    return
  fi

  local new_path="$parent_dir/$new_base_name"
  mv "$folder_path" "$new_path"
  echo "[INFO] Renamed: $base_name → $new_base_name"
}

# ----------------------------------------------------------------------------
# main(): Entry point
# Globals:
#   None
# Arguments:
#   $@ - CLI args
# Outputs:
#   Runs child script per folder and renames folder
# ----------------------------------------------------------------------------
main() {
  check_dependencies

  if [[ $# -lt 4 ]]; then
    echo "Usage: $0 <parent_dir> <script> <old> <new> [-- extra args]" >&2
    exit 1
  fi

  local parent_dir=$1
  local script_to_run=$2
  local old_str=$3
  local new_str=$4
  shift 4

  local -a EXTRA_ARGS=()
  if [[ $# -gt 0 ]]; then
    if [[ $1 == "--" ]]; then shift; fi
    EXTRA_ARGS=("$@")
  fi

  if [[ ! -d "$parent_dir" ]]; then
    echo "[ERROR] Directory not found: $parent_dir" >&2
    exit 1
  fi

  if [[ ! -x "$script_to_run" ]]; then
    echo "[ERROR] Not executable or missing: $script_to_run" >&2
    exit 1
  fi

  local count=0

  echo "[INFO] Starting batch run in: $parent_dir"
  echo "[INFO] Using script: $script_to_run"
  echo "[INFO] Replacing \"$old_str\" → \"$new_str\" in folder names"
  echo

  for dir in "$parent_dir"/*/; do
    [[ -d "$dir" ]] || continue

    echo "[INFO] Processing folder: $dir"
    echo "[DEBUG] Command: $script_to_run \"$dir\" ${EXTRA_ARGS[*]-}"

    "$script_to_run" -i "$dir" --quiet "${EXTRA_ARGS[@]}"
    rename_folder "$dir" "$old_str" "$new_str"
    count=$((count + 1))
    echo
  done

  echo "[INFO] Batch run complete. Processed $count folders."
}

main "$@"
