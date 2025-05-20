#!/bin/bash

# This script should not be executed directly. It provides a library function.
# It assumes that necessary helper functions (get_sequence_file_url, get_state_param, to_epoch)
# have already been sourced by the calling script.

# Performs a binary search to find the sequence number of the state file
# whose timestamp is closest to, but not after, the target_epoch.
#
# Arguments:
#   $1: effective_base_url     - The base URL for constructing sequence file URLs.
#   $2: target_epoch           - The target timestamp in Unix epoch seconds.
#   $3: low_bound_seq          - The lowest sequence number to start the search from.
#   $4: high_bound_seq         - The highest sequence number to consider in the search.
#
# Output:
#   - If successful, echoes the found sequence number to stdout.
#   - Prints warnings to stderr for non-critical issues (e.g., unparseable timestamps).
#
# Returns:
#   - 0 if a suitable sequence number is found and echoed.
#   - 1 if no suitable sequence number is found within the given bounds.
#   - Other non-zero values for critical internal errors (though less likely with current design).
perform_binary_search_for_sequence() {
    local effective_base_url="$1"
    local target_epoch="$2"
    local low_bound_seq="$3"
    local high_bound_seq="$4"

    local result_sequence_number=-1
    local mid_point mid_url mid_timestamp_str mid_epoch

    # Ensure numeric comparison for bounds
    low_bound_seq=$((10#$low_bound_seq))
    high_bound_seq=$((10#$high_bound_seq))

    while [ "$low_bound_seq" -le "$high_bound_seq" ]; do
        mid_point=$(( (low_bound_seq + high_bound_seq) / 2 ))

        mid_url=$(get_sequence_file_url "$effective_base_url" "$mid_point")
        if [ $? -ne 0 ]; then
            # This should ideally not happen if mid_point is always numeric.
            echo "Error (search): Could not generate URL for sequence $mid_point. This may indicate a problem with sequence bounds." >&2
            # Attempt to recover by reducing the search space, but this is an unexpected state.
            high_bound_seq=$((mid_point - 1))
            continue
        fi

        mid_timestamp_str=$(get_state_param "$mid_url" "timestamp")
        if [ $? -ne 0 ] || [ -z "$mid_timestamp_str" ]; then
            # Failed to get timestamp (e.g., file not found, parameter missing).
            # This usually means the sequence mid_point is too high or does not exist yet.
            # So, we search in the lower half.
            # echo "Debug (search): Timestamp for sequence $mid_point not found or empty. URL: $mid_url" >&2
            high_bound_seq=$((mid_point - 1))
            continue
        fi

        mid_epoch=$(to_epoch "$mid_timestamp_str")
        if [ $? -ne 0 ]; then
            # Failed to parse the timestamp obtained for the sequence file.
            echo "Warning (search): Could not parse timestamp '$mid_timestamp_str' for sequence $mid_point (URL: $mid_url). Skipping this sequence." >&2
            # Treat this sequence as unusable. Since we don't know if it's too early or too late,
            # a common strategy is to assume it's problematic and search in the lower half
            # to be conservative, or one could try to implement more complex logic.
            # For simplicity, if it's invalid, we act as if it's "too high" or "not the one".
            high_bound_seq=$((mid_point - 1))
            continue
        fi

        if [ "$mid_epoch" -le "$target_epoch" ]; then
            # The timestamp of this sequence (mid_point) is less than or equal to the target.
            # This makes mid_point a potential candidate for our result.
            # We store it and try to find an even later sequence (closer to target_epoch)
            # in the upper half of the current search space.
            result_sequence_number=$mid_point
            low_bound_seq=$((mid_point + 1))
        else
            # The timestamp of this sequence (mid_point) is after the target_epoch.
            # This sequence is too new. We must search in the lower half.
            high_bound_seq=$((mid_point - 1))
        fi
    done

    if [ "$result_sequence_number" -eq -1 ]; then
        # No sequence file was found whose timestamp is <= target_epoch within the given bounds.
        # This can happen if target_epoch is earlier than the timestamp of the lowest sequence number.
        return 1 # Indicate no suitable sequence found
    else
        echo "$result_sequence_number" # Output the found sequence number
        return 0 # Indicate success
    fi
}
