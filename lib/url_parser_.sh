#!/bin/bash

# Parses the input URL and prepares the base URL for operations.
# This function determines the correct directory URL that directly contains
# state.txt and the sequence number subdirectories.
#
# Arguments:
#   $1: input_url - The URL provided by the user.
#   $2: current_period - The current replication period (e.g., "hour").
#   $3: is_osm_like - "true" if the URL structure is like planet.osm.org, "false" otherwise.
#
# Output:
#   Prints the effective base directory URL to stdout.
#   e.g., https://planet.osm.org/replication/hour/ OR https://custom.server/my-data/
# Returns:
#   0 on success.
parse_and_prepare_base_url() {
    local input_url="$1"
    local current_period="$2"
    local is_osm_like="$3"

    local base_dir

    # Remove potential query strings and fragments from the URL
    base_dir="${input_url%%[?#]*}"

    # Phase 1: Normalize to a directory path by stripping known filenames.
    # This sed expression attempts to find and remove:
    #   - /<3digits>/<3digits>/<3digits>.state.txt (sequence file)
    #   - /state.txt (period state file)
    # and replaces them with a trailing slash, effectively getting the parent directory.
    base_dir=$(echo "$base_dir" | sed -E 's!(/[0-9]{3}/[0-9]{3}/[0-9]{3})?([/.]state\.txt)$!/!')

    # Ensure the path ends with a slash for consistent processing,
    # if it's not empty and doesn't already have one.
    # if [[ -n "$base_dir" && "${base_dir: -1}" != "/" ]]; then
    #     base_dir+="/"
    # fi

    if [[ "$is_osm_like" == "true" ]];then
        # For OSM-like structures, the effective base URL should point to the period-specific directory
        # (e.g., .../replication/hour/).

        local expected_period_suffix="${current_period}/"
        # Check if the current base_dir already ends with the expected period suffix
        if [[ "$base_dir" == *"/$expected_period_suffix" ]]; then
            # It's already the correct period directory (e.g., https://host.com/repl/hour/).
            : # Do nothing, base_dir is correctly formatted.
        else
            # Assume base_dir is the replication root (e.g., https://host.com/repl/)
            # and append the current_period to it.
            # Remove a trailing slash from base_dir if present, then add period and a new slash.
            base_dir="${base_dir%/}/${current_period}/"
        fi
    else
        # For non-OSM-like structures, base_dir (after stripping filenames)
        # is already assumed to be the directory containing state.txt and sequence folders.
        # The 'current_period' variable is not used for further path construction here.
        : # Do nothing, base_dir is assumed to be correct as is.
    fi

    # Final check to ensure the resulting URL ends with a slash,
    # if it's not empty and doesn't already have one.
    if [[ -n "$base_dir" && "${base_dir: -1}" != "/" ]]; then
        base_dir+="/"
    fi

    echo "$base_dir"
    return 0
}
