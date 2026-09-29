#!/usr/bin/env bash
# detox: strip control characters and zero-width characters from .txt files,
# in place.

set -euo pipefail
IFS=$'\n\t'

VERSION='1.4.0'
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly VERSION SCRIPT_DIR

load_config() {
	local config="$SCRIPT_DIR/detox.conf"
	if [[ ! -f $config ]]; then
		echo "[FAIL] Configuration file not found: $config" >&2
		exit 1
	fi
	# shellcheck source=detox.conf
	source "$config"
}

log_info() { echo -e "${BLUE}[INFO] $1${RESET}"; }
log_error() { echo -e "${RED}[FAIL] $1${RESET}" >&2; }
log_success() { echo -e "${GREEN}[OK] $1${RESET}"; }
log_cleaned() { last_message="${CYAN}[CLEAN] $1${RESET}"; }

check_dependencies() {
	if ! command -v perl &>/dev/null; then
		log_error "Perl is required but not installed."
		exit 1
	fi
}

init_state() {
	input_dir=./data
	ignore_zwc=false
	dry_run=false
	debug=false
	auto_confirm=false
	quiet=false
	cleaned=0
	skipped=0
	failed=0
	deferred_logs=()
	last_message='Scanning...'
}

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -i, --input <dir>   Directory to scan for .txt files (default: ./data)
  -n, --dry-run       Show what would be cleaned without changing files
  -d, --debug         Report how many lines changed in each file
  -y, --yes           Clean without asking for each file
  --ignore-zwc        Only remove control characters
  --quiet             Hide the progress bar
  -h, --help          Show this help
  -v, --version       Show the version
EOF
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case $1 in
		-i | --input)
			if [[ $# -lt 2 ]]; then
				log_error "$1 needs a directory"
				exit 1
			fi
			input_dir=${2%/}
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
		-h | --help)
			usage
			exit 0
			;;
		-v | --version)
			echo "detox $VERSION"
			exit 0
			;;
		*)
			log_error "Unknown option: $1"
			usage >&2
			exit 1
			;;
		esac
	done
}

show_progress() {
	local current=$1 total=$2 width=30 filled bar
	filled=$((current * width / total))
	printf -v bar '%*s' "$filled" ''
	bar=${bar// /#}
	printf -v bar '%-*s' "$width" "$bar"
	printf '\r[%s] %3d%% (%d/%d)' "${bar// /-}" $((current * 100 / total)) "$current" "$total"
}

# Redraws the progress bar with the latest message under it, over the two
# lines printed before the loop
handle_progress() {
	[[ $quiet == true ]] && return
	printf '\033[1A\033[2K\033[1A\033[2K'
	show_progress "$@"
	echo
	echo -e "$last_message"
}

clean_file() {
	local file=$1 regex=$PERL_BINARY_REGEX tmp err
	[[ $ignore_zwc == true ]] || regex+="; $PERL_ZWC_REGEX"

	tmp=$(mktemp)
	err=$(mktemp)
	# shellcheck disable=SC2064 # expand the paths now, while they're set
	trap "rm -f -- '$tmp' '$err'; trap - RETURN" RETURN

	if ! perl -pe "$regex" "$file" >"$tmp" 2>"$err"; then
		deferred_logs+=("${RED}[PERL FAIL] $file: $(<"$err")${RESET}")
		failed=$((failed + 1))
		return
	fi

	if cmp -s "$file" "$tmp"; then
		log_cleaned "Already clean: $file"
		return
	fi

	if [[ $dry_run == true ]]; then
		log_cleaned "[DRY-RUN] Would clean: $file"
		return
	fi

	if [[ $auto_confirm != true ]]; then
		local answer
		read -rp "Clean $file? [y/N] " answer
		if [[ ! $answer =~ ^[Yy]$ ]]; then
			skipped=$((skipped + 1))
			return
		fi
	fi

	if [[ $debug == true ]]; then
		local changes
		changes=$(diff "$file" "$tmp" | grep -c '^<' || true)
		deferred_logs+=("${BLUE}[DEBUG] $file: $changes line(s) changed${RESET}")
	fi

	# Write through the original file to keep its permissions
	cat "$tmp" >"$file"
	echo "$file" >>"$input_dir/clean.log"
	cleaned=$((cleaned + 1))
	log_cleaned "Cleaned: $file"
}

run_cleaning() {
	if [[ ! -d $input_dir ]]; then
		log_error "Not a directory: $input_dir"
		exit 1
	fi

	local files=() index file
	while IFS= read -r -d '' file; do
		files+=("$file")
	done < <(find "$input_dir" -type f -name '*.txt' -print0)
	log_info "Found ${#files[@]} .txt file(s) in $input_dir"
	if [[ ${#files[@]} -eq 0 ]]; then
		return
	fi

	[[ $dry_run == true ]] || echo "# detox clean log - $(date)" >"$input_dir/clean.log"
	[[ $quiet == true ]] || printf '\n\n'

	for index in "${!files[@]}"; do
		file=${files[index]}
		if [[ -r $file ]]; then
			clean_file "$file"
		else
			deferred_logs+=("${YELLOW}[SKIP] Unreadable: $file${RESET}")
			skipped=$((skipped + 1))
		fi
		handle_progress $((index + 1)) "${#files[@]}"
	done

	[[ $quiet == true ]] || echo
	log_success "Done: $cleaned cleaned, $skipped skipped, $failed failed."
	[[ $dry_run == true ]] || log_info "Log saved to $input_dir/clean.log"

	# Bash 3.2 treats an empty array as unset under set -u
	if [[ ${#deferred_logs[@]} -gt 0 ]]; then
		local line
		for line in "${deferred_logs[@]}"; do
			echo -e "$line"
		done
	fi
}

main() {
	load_config
	check_dependencies
	init_state
	parse_args "$@"
	run_cleaning
}

main "$@"
