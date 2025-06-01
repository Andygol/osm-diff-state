#!/bin/bash

# Color definitions for enhanced output (POSIX compatible)
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    # Terminal supports colors
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    PURPLE=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    WHITE=$(tput setaf 7)
    GRAY=$(tput setaf 8 2>/dev/null || tput setaf 7)
    BOLD=$(tput bold)
    DIM=$(tput dim 2>/dev/null || echo "")
    UNDERLINE=$(tput smul)
    RESET=$(tput sgr0)
else
    # No color support
    RED="" GREEN="" YELLOW="" BLUE="" PURPLE="" CYAN="" WHITE="" GRAY=""
    BOLD="" DIM="" UNDERLINE="" RESET=""
fi

# ASCII symbols for visual enhancement (compatible across shells)
ARROW=">"
BULLET="*"
STAR="*"
CHECK="+"
GEAR="¤"
INFO="i"
WARNING="!"

# Function to create divider
print_divider() {
    local char="${1:--}"
    local width="${2:-78}"
    local color="${3:-$CYAN}"

    printf "${color}"
    printf "%*s" "$width" | tr ' ' "$char"
    printf "${RESET}\n"
}

# Function to create a header
print_header() {
    local title="$1"
    local subtitle="$2"
    local title_len=${#title}
    local subtitle_len=${#subtitle}
    local padding

    echo
    print_divider "=" 78 "$PURPLE"

    # Center title
    padding=$(( (78 - title_len) / 2 ))
    printf "${BOLD}${WHITE}%*s%s${RESET}\n" "$padding" "" "$title"

    # Center subtitle if provided
    if [[ -n "$subtitle" ]]; then
        padding=$(( (78 - subtitle_len) / 2 ))
        printf "${DIM}${GRAY}%*s%s${RESET}\n" "$padding" "" "$subtitle"
    fi

    print_divider "=" 78 "$PURPLE"
    echo
}

# Function to print styled sections
print_section() {
    local title="$1"
    local icon="$2"
    local color="${3:-$BLUE}"

    printf "\n${BOLD}${color}${icon} %s${RESET}\n" "$title"
    print_divider "-" 40 "$color"
}

# Function to print parameter with styling
print_param() {
    local param="$1"
    local desc="$2"
    local required="${3:-false}"

    if [[ "$required" == "true" ]]; then
        printf "  ${BOLD}${GREEN}%-16s${RESET} ${ARROW} %s\n" "$param" "$desc"
    else
        printf "  ${DIM}${BOLD}${YELLOW}%-16s${RESET} ${ARROW} %s\n" "$param" "$desc"
    fi
}

# Function to print option with styling
print_option() {
    local option="$1"
    local desc="$2"
    local default="$3"

    printf "  ${BOLD}${CYAN}%-25s${RESET} ${BULLET} %s" "$option" "$desc"
    if [[ -n "$default" ]]; then
        printf " ${DIM}${GRAY}(Default: %s)${RESET}" "$default"
    fi
    printf "\n"
}

# Function to print example with syntax highlighting
print_example() {
    local cmd="$1"
    local desc="$2"

    printf "  ${DIM}${GRAY}${BULLET}"
    if [[ -n "$desc" ]]; then
        printf " %s${RESET}" "$desc"
    fi
    printf "\n"
    printf "  ${GREEN}%s${RESET}" "$cmd"
    printf "\n\n"
}

# Function to print log level info
print_log_level() {
    local level="$1"
    local desc="$2"
    local color="$3"

    printf "    ${BOLD}${color}%-8s${RESET} - %s\n" "$level" "$desc"
}

# Enhanced usage function with visual styling
show_usage() {
    local script_name="${1:-osm-diff-state.sh}"
    local default_repl_url="${DEFAULT_URL_FOR_USAGE:-https://planet.osm.org/replication/}"

    print_header "OpenStreetMap replication diff search tool" "Find OSM replication files by timestamp"

    # Usage syntax
    print_section "USAGE" "$GEAR" "$BLUE"
    printf "  ${BOLD}${WHITE}%s${RESET} ${GREEN}<period>${RESET} ${GREEN}<timestamp>${RESET} ${DIM}${YELLOW}[replication_url]${RESET} ${DIM}${YELLOW}[options]${RESET}\n\n" "$script_name"

    # Parameters section
    print_section "PARAMETERS" "$ARROW" "$GREEN"
    print_param "period" "Replication period (${BOLD}day, hour, minute${RESET})" "true"
    print_param "timestamp" "Date and time in ${UNDERLINE}${BOLD}YYYY-MM-DD${DIM}[<T| >HH[:MM[:SS]]]${RESET} format" "true"
    print_param "replication_url" "URL to replication data ${DIM}(Optional)${RESET}" "false"

    printf "\n  ${DIM}${GRAY}${INFO} Default URL: ${UNDERLINE}%s${RESET}${DIM}${GRAY}${RESET}\n" "$default_repl_url"
    printf "  ${DIM}${GRAY}${INFO} URL can be root, period directory, or direct state.txt path${RESET}\n"

    # Options section
    print_section "OPTIONS" "$GEAR" "$CYAN"
    print_option "--osm-like[=<true|false>]" "Define replication URL structure" "true"
    print_option "--log-level=<level>" "Set logging level ${DIM}(debug|info|warn|error|fatal)${RESET}" "info"
    print_option "-v, --verbose" "Enable debug logging"
    print_option "-q, --quiet" "Show only errors"
    print_option "-h, --help" "Show this help message"

    # Logging section
    print_section "LOGGING LEVELS" "$INFO" "$PURPLE"
    printf "  ${DIM}${GRAY}${INFO} All logs go to stderr, results to stdout${RESET}\n\n"
    print_log_level "debug" "Detailed debugging information" "$GRAY"
    print_log_level "info" "General progress information" "$BLUE"
    print_log_level "warn" "Warning messages" "$YELLOW"
    print_log_level "error" "Error messages only" "$RED"
    print_log_level "fatal" "Critical errors only" "$RED"

    # Examples section
    print_section "EXAMPLES" "$STAR" "$GREEN"
    print_example "$script_name day \"2024-05-16\"" "Basic daily replication"
    print_example "$script_name hour \"2024-05-16T12:00\" --verbose" "Hourly with debug output"
    print_example "$script_name minute \"2024-05-16 12:00:00\" --log-level=debug" "Minute-level with specific log level"
    print_example "$script_name hour \"2024-05-16T12:00\" \"$default_repl_url\" --osm-like=true --quiet" "Custom URL with OSM structure"
    print_example "$script_name minute \"2024-05-16 12:00:00\" \"https://custom.server/osm/minute-diffs/\" --osm-like=false" "Non-OSM structure"
    print_example "$script_name day \"2024-05-16\" \"https://my-mirror.com/planet/day/000/001/234.state.txt\"" "Direct state file URL"

    # Description section
    print_section "DESCRIPTION" "(I)" "$BLUE"
    cat << 'DESC'
  This script finds the closest OpenStreetMap replication file for
  a given timestamp using binary search (bisection). It returns the
  full URL to the found state file.

  Key Features:
  * Finds nearest state file with timestamp <= requested time
  * Supports various replication URL structures
  * Configurable logging levels
  * Binary search for efficient file discovery

  Important Notes:
  * The --osm-like flag determines URL interpretation
  * All logging goes to stderr to preserve pipeline compatibility
  * Main result is always printed to stdout regardless of log level
DESC

    # Footer
    echo
    print_divider "-" 78 "$DIM"
    printf "${DIM}${GRAY}%s${RESET}\n" "For more help, visit: https://wiki.openstreetmap.org/wiki/Planet.osm/diffs"
    print_divider "-" 78 "$DIM"
    echo

    exit 1
}
