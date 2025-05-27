#!/bin/bash

# This script should not be executed directly. It provides library functions.

# Checks if a remote URL is accessible.
# Uses wget in spider mode with a timeout and limited retries.
#
# Arguments:
#   $1: url_to_check - The URL to check for accessibility.
#   $2: (Optional) timeout_seconds - Timeout for the connection attempt (default: 10 seconds).
#   $3: (Optional) retries - Number of retries (default: 2).
#
# Output:
#   - Uses logging system for status messages
#
# Returns:
#   - 0 if the URL is accessible (wget --spider returns 0).
#   - Non-zero (wget's exit code) if the URL is not accessible or an error occurs.
check_url_accessibility() {
    local url_to_check="$1"
    local timeout_seconds="${2:-10}" # Default timeout 10 seconds
    local retries="${3:-2}"          # Default 2 retries

    if [ -z "$url_to_check" ]; then
        log_error "check_url_accessibility: No URL provided."
        return 127 # Invalid argument
    fi

    log_debug "Checking URL accessibility: $url_to_check (timeout: ${timeout_seconds}s, retries: $retries)"

    # Using wget --spider. It tries to connect and get headers.
    # -q: quiet mode
    # --spider: spider mode (don't download, just check)
    # -T, --timeout=SECONDS: set network timeout
    # -t, --tries=NUMBER: set number of retries (0 for infinite)
    # We use our own retry loop to print messages and control flow better if needed.

    local attempt=1
    local max_attempts=$((retries + 1)) # Total attempts including the first one

    while [ "$attempt" -le "$max_attempts" ]; do
        if [ "$attempt" -gt 1 ]; then
            log_debug "Retrying URL check (attempt $attempt/$max_attempts): $url_to_check"
            # Optional: add a small delay between retries
            # sleep 2
        fi

        wget --spider -q -T "$timeout_seconds" -t 1 "$url_to_check" # -t 1 means 1 try (no wget internal retries)
        local wget_exit_code=$?

        if [ "$wget_exit_code" -eq 0 ]; then
            log_debug "URL is accessible: $url_to_check"
            return 0 # Success
        fi

        log_debug "URL check attempt $attempt failed with exit code $wget_exit_code"
        attempt=$((attempt + 1))
    done

    log_error "URL is not accessible after $max_attempts attempts or timed out: $url_to_check"
    return 1 # General error, or could return last wget_exit_code
}
