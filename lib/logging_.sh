#!/bin/bash

# Logging library with 5 levels: DEBUG, INFO, WARN, ERROR, FATAL
# All log messages go to stderr to avoid interfering with script output to stdout

# Log levels (numeric values for comparison)
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_FATAL=4

# Default log level (can be overridden)
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Color codes for different log levels (if terminal supports colors)
if [[ -t 2 ]] && command -v tput >/dev/null 2>&1; then
    readonly COLOR_DEBUG="\033[36m"    # Cyan
    readonly COLOR_INFO="\033[32m"     # Green
    readonly COLOR_WARN="\033[33m"     # Yellow
    readonly COLOR_ERROR="\033[31m"    # Red
    readonly COLOR_FATAL="\033[35m"    # Magenta
    readonly COLOR_RESET="\033[0m"     # Reset
else
    readonly COLOR_DEBUG=""
    readonly COLOR_INFO=""
    readonly COLOR_WARN=""
    readonly COLOR_ERROR=""
    readonly COLOR_FATAL=""
    readonly COLOR_RESET=""
fi

# Convert log level name to numeric value
# Arguments:
#   $1 - Log level name (debug, info, warn, error, fatal - case insensitive)
# Output:
#   Prints numeric log level to stdout
# Returns:
#   0 on success, 1 if invalid level name
log_level_to_numeric() {
    # local level_name="${1,,}" # Convert to lowercase in Baah 4.0
    local level_name="$(echo $1 | tr '[:upper:]' '[:lower:]' )" # Convert to lowercase in Bash and Zsh

    case "$level_name" in
        debug) echo $LOG_LEVEL_DEBUG ;;
        info)  echo $LOG_LEVEL_INFO ;;
        warn)  echo $LOG_LEVEL_WARN ;;
        error) echo $LOG_LEVEL_ERROR ;;
        fatal) echo $LOG_LEVEL_FATAL ;;
        *) return 1 ;;
    esac
    return 0
}

# Set the global log level
# Arguments:
#   $1 - Log level (debug, info, warn, error, fatal - case insensitive)
# Returns:
#   0 on success, 1 if invalid level
set_log_level() {
    local new_level
    new_level=$(log_level_to_numeric "$1")
    if [ $? -eq 0 ]; then
        LOG_LEVEL=$new_level
        return 0
    else
        echo "Error: Invalid log level '$1'. Valid levels: debug, info, warn, error, fatal" >&2
        return 1
    fi
}

# Internal function to log a message
# Arguments:
#   $1 - Numeric log level
#   $2 - Log level name
#   $3 - Color code
#   $4 - Message
_log() {
    local msg_level="$1"
    local level_name="$2"
    local color="$3"
    local message="$4"

    # Only log if message level is >= current log level
    if [ "$msg_level" -ge "$LOG_LEVEL" ]; then
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        printf "${color}[%s] %s: %s${COLOR_RESET}\n" "$timestamp" "$level_name" "$message" >&2
    fi
}

# Logging functions for each level
log_debug() {
    _log $LOG_LEVEL_DEBUG "DEBUG" "$COLOR_DEBUG" "$*"
}

log_info() {
    _log $LOG_LEVEL_INFO "INFO" "$COLOR_INFO" "$*"
}

log_warn() {
    _log $LOG_LEVEL_WARN "WARN" "$COLOR_WARN" "$*"
}

log_error() {
    _log $LOG_LEVEL_ERROR "ERROR" "$COLOR_ERROR" "$*"
}

log_fatal() {
    _log $LOG_LEVEL_FATAL "FATAL" "$COLOR_FATAL" "$*"
}

# Convenience function to log and exit with error code
# Arguments:
#   $1 - Error message
#   $2 - (Optional) Exit code (default: 1)
log_fatal_and_exit() {
    local message="$1"
    local exit_code="${2:-1}"

    log_fatal "$message"
    exit "$exit_code"
}
