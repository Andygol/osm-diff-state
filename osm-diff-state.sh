#!/bin/bash
set -e

# Constants
readonly VALID_PERIODS="day hour minute"
readonly DEFAULT_URL="https://planet.osm.org/replication/"

# Show usage information
show_usage() {
    cat <<USAGE
Find OpenStreetMap replication file for a specific timestamp

Usage: $0 <period> <timestamp> [replication_url]

Parameters:
    period          - Replication period (day, hour, minute)
    timestamp       - Date and time in YYYY-MM-DD[THH:MM:SS] format
    replication_url - (optional) URL to the replication server
                      default: ${DEFAULT_URL}

Examples:
    $0 day "2024-05-16"
    $0 day "2024-05-16 12:00:00"
    $0 hour "2024-05-16 12:00:00"
    $0 hour "2024-05-16T12:00:00"
    $0 minute "2024-05-16 12:00:00" "https://planet.openstreetmap.org/replication/"

Description:
    This script finds the closest OpenStreetMap replication file for a given timestamp
    using binary search (bisection). It returns the full URL to the found state file.
    The script will find the nearest state file with timestamp less than or equal to
    the requested time.
USAGE
    exit 1
}

# Helper functions
to_epoch() {
    date -d "$1" +%s 2>/dev/null || {
        echo "Error: Invalid date format. Use YYYY-MM-DD[THH:MM:SS]" >&2
        exit 1
    }
}

validate_period() {
    local period="$1"
    [[ " $VALID_PERIODS " == *" $period "* ]] || {
        echo "Error: Period must be one of: $VALID_PERIODS" >&2
        exit 1
    }
}

# Get state.txt content and extract parameter
get_state_param() {
    local url="$1"
    local param="$2"
    local content

    content=$(wget --max-redirect=5 -q -O - "$url" 2>/dev/null) || {
        echo "Error: Failed to fetch $url" >&2
        return 1
    }

    echo "$content" | grep "^${param}=" | cut -d'=' -f2 | sed 's/\\//g; s/Z$//' | tr -d '\r\n '
}

# Generate URL for state file by sequence number
get_state_url() {
    local base_url="$1"
    local period="$2"
    local seq="$3"
    local padded_seq=$(printf "%09d" "$seq")
    echo "${base_url%/}/${period}/${padded_seq:0:3}/${padded_seq:3:3}/${padded_seq:6:3}.state.txt"
}

# Main bisection function
find_state_file() {
    local period="$1"
    local target_ts="$2"
    local base_url="$3"
    local target_epoch=$(to_epoch "$target_ts")

    # Get current state
    local current_url="${base_url%/}/${period}/state.txt"
    local latest_seq=$(get_state_param "$current_url" "sequenceNumber")
    [ -z "$latest_seq" ] && {
        echo "Error: Failed to get current state" >&2
        exit 1
    }

    # Get timestamp of current state
    local current_ts=$(get_state_param "$current_url" "timestamp")
    local current_epoch=$(to_epoch "$current_ts")

    # Check if target time is in the future
    if [ "$target_epoch" -gt "$current_epoch" ]; then
        echo "Warning: Requested time $target_ts is in the future. Using latest available state ($current_ts)" >&2
        get_state_url "$base_url" "$period" "$latest_seq"
        return 2
    fi

    # Binary search
    local low=0 high=$((10#$latest_seq)) result_seq=-1

    while [ $low -le $high ]; do
        local mid=$(( (low + high) / 2 ))
        local mid_url=$(get_state_url "$base_url" "$period" "$mid")
        local mid_ts=$(get_state_param "$mid_url" "timestamp")

        [ -z "$mid_ts" ] && {
            high=$((mid - 1))
            continue
        }

        local mid_epoch=$(to_epoch "$mid_ts")

        if [ $mid_epoch -le $target_epoch ]; then
            result_seq=$mid
            low=$((mid + 1))
        else
            high=$((mid - 1))
        fi
    done

    [ $result_seq -eq -1 ] && {
        echo "Error: No suitable state file found for $target_ts" >&2
        exit 1
    }

    get_state_url "$base_url" "$period" "$result_seq"
}

# Parse command line arguments
[ $# -lt 2 ] && show_usage

period="$1"
timestamp="${2/T/ }"  # Replace T with space if present
base_url="${3:-$DEFAULT_URL}"

validate_period "$period"

# Find and output the state file URL
find_state_file "$period" "$timestamp" "$base_url"
exit $?
