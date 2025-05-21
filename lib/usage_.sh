#!/bin/bash

# Displays usage information for the script.
# Arguments:
#   $1 - The script name (e.g., $0 from the main script).
# Environment Variables:
#   DEFAULT_URL_FOR_USAGE - The default replication URL to display in usage.
show_usage() {
    local script_name="${1:-osm-diff-state.sh}" # Script name from the main file
    local default_repl_url="${DEFAULT_URL_FOR_USAGE:-https://planet.osm.org/replication/}"

    cat <<USAGE
Find OpenStreetMap replication file for a specific timestamp.

Usage: $script_name <period> <timestamp> [replication_url] [options]

Parameters:
    period          - Replication period (day, hour, minute).
    timestamp       - Date and time in YYYY-MM-DD[THH:MM:SS] format.
    replication_url - (Optional) URL to the replication data.
                      This can be the root of replication (e.g., https://planet.osm.org/replication/),
                      a specific period directory (e.g., .../replication/hour/),
                      or a path to a state.txt or sequence file.
                      Default: ${default_repl_url}

Options:
    --osm-like[=<true|false>] - Define if the replication_url structure is like planet.osm.org.
                                If true, <period> is expected as a path segment (e.g., .../replication/<period>/).
                                If false, replication_url directly points to a directory containing
                                state.txt and sequence number folders for the specified <period>.
                                The <period> argument is used for context but not to derive path segments
                                from the replication_url after initial parsing.
                                Providing just '--osm-like' without a value is equivalent to '--osm-like=true'.
                                (Default: true)
    -h, --help                - Show this help message.

Examples:
    $script_name day "2024-05-16"
    $script_name hour "2024-05-16T12:00" "https://planet.osm.org/replication/" --osm-like=true
    $script_name minute "2024-05-16 12:00:00" "https://custom.server/osm/minute-diffs/" --osm-like=false
    $script_name hour "2024-05-16T12:00" # Uses default URL and osm-like structure
    $script_name day "2024-05-16" "https://my-mirror.com/planet/day/000/001/234.state.txt" # Will parse correctly

Description:
    This script finds the closest OpenStreetMap replication file for a given timestamp
    using binary search (bisection). It returns the full URL to the found state file.
    The script will find the nearest state file with a timestamp less than or equal to
    the requested time. The interpretation of 'replication_url' depends on the --osm-like flag.
USAGE
    exit 1
}
