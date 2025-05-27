#!/bin/bash

# Converts a date string to a Unix epoch timestamp.
# Handles various date/time formats and 'Z' (Zulu/UTC) suffix.
# Supports both macOS (BSD date) and Linux (GNU date) `date` command syntax.
# Arguments:
#   $1 - The date string to convert (e.g., "YYYY-MM-DDTHH:MM:SSZ", "YYYY-MM-DD HH:MM", "YYYY-MM-DD").
# Output:
#   Prints the epoch timestamp to stdout.
# Returns:
#   0 on success, 1 on failure (and prints an error message to stderr).
to_epoch() {
    local input_date_string="${1%Z}" # Remove 'Z' suffix if present, as `date` handles UTC interpretation.
    input_date_string="${input_date_string/T/ }" # Replace 'T' with space for compatibility with `date` command.

    log_debug "Converting date string: '$1' -> processed: '$input_date_string'"

    # Internal error reporting function for to_epoch
    _to_epoch_error() {
        local error_msg="Invalid date format '$1'. Use YYYY-MM-DD[THH[:MM[:SS]]][Z]"
        log_error "$error_msg"
        return 1
    }

    # Attempt to parse date using macOS/BSD `date` syntax
    _try_parse_mac() {
        local date_to_parse="$1"
        local fmt # Loop variable for format strings
        local epoch_time # Stores the result of date conversion

        log_debug "Attempting to parse date using macOS/BSD date syntax: '$date_to_parse'"

        # Order formats from most specific to least specific
        for fmt in \
            "%Y-%m-%d %H:%M:%S" \
            "%Y-%m-%d %H:%M" \
            "%Y-%m-%d %H" \
            "%Y-%m-%d"
        do
            log_debug "Trying format: '$fmt'"
            epoch_time=$(date -j -f "$fmt" "$date_to_parse" "+%s" 2>/dev/null)
            if [ $? -eq 0 ]; then
                log_debug "Successfully parsed with format '$fmt' -> epoch: $epoch_time"
                echo "$epoch_time"
                return 0
            else
                log_debug "Format '$fmt' could not be applied to the timestamp '$date_to_parse'"
            fi
        done
        log_warn "All macOS/BSD date formats failed for: '$date_to_parse'"
        return 1 # Failed to parse with any format
    }

    # Attempt to parse date using Linux/GNU `date` syntax
    _try_parse_linux() {
        local date_to_parse="$1"
        local epoch_time # Stores the result of date conversion

        log_debug "Attempting to parse timestamp using Linux/GNU date syntax: '$date_to_parse'"

        epoch_time=$(date -d "$date_to_parse" "+%s" 2>/dev/null)
        if [ $? -eq 0 ]; then
            log_debug "Successfully parsed with GNU date -> epoch: $epoch_time"
            echo "$epoch_time"
            return 0
        else
            log_warn "GNU date parsing failed for: '$date_to_parse'"
            return 1 # Failed to parse
        fi
    }

    local parsed_epoch
    local system_type="$(uname)"

    log_debug "Detected system type: $system_type"

    if [[ "$system_type" == "Darwin" ]]; then
        log_debug "Using macOS/BSD date parsing"
        parsed_epoch=$(_try_parse_mac "$input_date_string")
    else
        log_debug "Using Linux/GNU date parsing"
        parsed_epoch=$(_try_parse_linux "$input_date_string")
    fi

    if [ -n "$parsed_epoch" ]; then
        log_debug "Successfully converted '$1' to epoch timestamp: $parsed_epoch"
        echo "$parsed_epoch"
        return 0
    else
        log_error "Failed to parse timestamp string: '$1'"
        _to_epoch_error "$1" # Pass original input for error message
        return 1
    fi
}
