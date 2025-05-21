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

    # Internal error reporting function for to_epoch
    _to_epoch_error() {
        echo "Error (to_epoch): Invalid date format '$1'. Use YYYY-MM-DD[THH[:MM[:SS]]][Z]" >&2
        return 1
    }

    # Attempt to parse date using macOS/BSD `date` syntax
    _try_parse_mac() {
        local date_to_parse="$1"
        local fmt # Loop variable for format strings
        local epoch_time # Stores the result of date conversion

        # Order formats from most specific to least specific
        for fmt in \
            "%Y-%m-%d %H:%M:%S" \
            "%Y-%m-%d %H:%M" \
            "%Y-%m-%d %H" \
            "%Y-%m-%d"
        do
            epoch_time=$(date -j -f "$fmt" "$date_to_parse" "+%s" 2>/dev/null)
            if [ $? -eq 0 ]; then
                echo "$epoch_time"
                return 0
            fi
        done
        return 1 # Failed to parse with any format
    }

    # Attempt to parse date using Linux/GNU `date` syntax
    _try_parse_linux() {
        local date_to_parse="$1"
        local epoch_time # Stores the result of date conversion

        epoch_time=$(date -d "$date_to_parse" "+%s" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "$epoch_time"
            return 0
        else
            return 1 # Failed to parse
        fi
    }

    local parsed_epoch

    if [[ "$(uname)" == "Darwin" ]]; then
        parsed_epoch=$(_try_parse_mac "$input_date_string")
    else
        parsed_epoch=$(_try_parse_linux "$input_date_string")
    fi

    if [ -n "$parsed_epoch" ]; then
        echo "$parsed_epoch"
        return 0
    else
        _to_epoch_error "$1" # Pass original input for error message
        return 1
    fi
}
