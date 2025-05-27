#!/bin/bash

# Validates if the provided period is one of the allowed values.
# Arguments:
#   $1 - The period string to validate.
# Environment Variables:
#   VALID_PERIODS_LIST - A space-separated string of valid period names (e.g., "day hour minute").
#                        If not set, a default list is used.
# Output:
#   Prints an error message to stderr if validation fails.
# Returns:
#   0 if the period is valid, 1 otherwise.
validate_period() {
    local period_to_validate="$1"
    # Use provided list or a default; ensure spaces around for robust matching.
    local valid_options=" ${VALID_PERIODS_LIST:-day hour minute} "

    log_debug "Validating period: '$period_to_validate'"

    if [[ "$valid_options" == *" $period_to_validate "* ]]; then
        log_debug "Period validation successful: '$period_to_validate' is valid"
        return 0 # Period is valid
    else
        local error_msg="Period must be one of: ${valid_options}"
        log_error "Period validation failed: '$period_to_validate' is not valid"
        log_error "Available periods: $valid_options"
        # echo "Error (validate_period): $error_msg" >&2
        return 1 # Period is invalid
    fi
}
