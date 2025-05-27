#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Define the directory where library scripts are located.
LIB_DIR="$(dirname "$0")/lib"
# Fallback if script is run from a different working directory where dirname "$0" is "."
[ ! -d "$LIB_DIR" ] && LIB_DIR="./lib"

# Source helper functions.
# Ensure these files exist in the LIB_DIR.
source "${LIB_DIR}/logging_.sh"      # Must be sourced first
source "${LIB_DIR}/usage_.sh"
source "${LIB_DIR}/date_.sh"
source "${LIB_DIR}/validation_.sh"
source "${LIB_DIR}/state_url_.sh"   # Contains get_state_param and get_sequence_file_url
source "${LIB_DIR}/url_parser_.sh"  # Contains parse_and_prepare_base_url
source "${LIB_DIR}/search_.sh"      # Contains perform_binary_search_for_sequence
source "${LIB_DIR}/network_.sh"     # Contains URL accessibility check

# --- Constants ---
# Default input URL if none is provided by the user.
readonly DEFAULT_INPUT_URL="https://planet.osm.org/replication/"
# List of valid period names for validation.
readonly VALID_PERIODS_LIST="day hour minute"


# --- Main Bisection Function ---
# Finds the OSM replication state file closest to (and not after) the target timestamp.
# Arguments:
#   $1: effective_base_url - The fully resolved URL to the directory containing
#                            state.txt and sequence subdirectories (e.g., .../hour/ or .../custom-data/).
#   $2: target_timestamp_str - The target date/time string.
# Output:
#   Prints the URL of the found state file to stdout.
# Returns:
#   0 on success.
#   1 on error (e.g., failed to fetch data, no suitable file found).
#   2 if the requested time is in the future (uses latest available state).
find_state_file() {
    local effective_base_url="$1"
    local target_timestamp_str="$2"
    local period="$3" # This is the period argument passed to the script.

    log_debug "Starting find_state_file with URL: $effective_base_url, target: $target_timestamp_str, period: $period"

    # Construct URL for the current (latest) state.txt for the given period/data source.
    local current_period_state_txt_url="${effective_base_url%/}/state.txt"
    log_debug "Current state URL: $current_period_state_txt_url"

    # Check either effective_base_url or current_period_state_txt_url for accessibility.
    # This is a more general check, as the state.txt might not exist but the base URL is valid.
    log_info "Checking URL accessibility: $effective_base_url"
    if ! check_url_accessibility "$effective_base_url"; then
        log_fatal_and_exit "URL accessibility check failed for: $effective_base_url" 1
    fi
    log_debug "URL accessibility check passed"

    # If the above passes, state.txt itself might still be missing,
    # but at least the server/path is generally responsive.

    local latest_sequence_number
    log_info "Fetching latest sequence number from: $current_period_state_txt_url"
    latest_sequence_number=$(get_state_param "$current_period_state_txt_url" "sequenceNumber") || {
        log_error "Failed to get current 'sequenceNumber' from $current_period_state_txt_url"
        log_error "This could be due to a missing state.txt, network issues not caught by the initial check, or incorrect URL."
        exit 1
    }
    log_debug "Latest sequence number: $latest_sequence_number"

    local latest_timestamp_str
    log_info "Fetching latest timestamp from: $current_period_state_txt_url"
    latest_timestamp_str=$(get_state_param "$current_period_state_txt_url" "timestamp") || {
        log_fatal_and_exit "Failed to get current 'timestamp' from $current_period_state_txt_url" 1
    }
    log_debug "Latest timestamp: $latest_timestamp_str"

    local latest_epoch
    latest_epoch=$(to_epoch "$latest_timestamp_str") || exit 1 # Convert latest state's time to epoch.
    log_debug "Latest epoch: $latest_epoch"

    local target_epoch
    target_epoch=$(to_epoch "$target_timestamp_str") || exit 1 # Convert target time to epoch; exit on failure.
    log_debug "Target epoch: $target_epoch"

    # Check if the target timestamp is in the future compared to the latest available state.
    if [ "$target_epoch" -gt "$latest_epoch" ]; then
        log_warn "Requested time '$target_timestamp_str' is in the future. Using latest available state ('$latest_timestamp_str')."
        # Check accessibility of the specific sequence file URL before printing
        local latest_seq_url
        latest_seq_url=$(get_sequence_file_url "$effective_base_url" "$latest_sequence_number")
        if [ $? -eq 0 ] && check_url_accessibility "$latest_seq_url" 5 1; then # Shorter timeout/retry for this specific file
             log_info "Returning latest sequence file URL: $latest_seq_url"
             echo "$latest_seq_url"
        else
            log_fatal_and_exit "Latest sequence file URL ($latest_seq_url) appears inaccessible or could not be generated." 1
        fi
        return 2 # Return special code for future timestamp.
    fi

    case $period in
        day)
            local divider=86400 # Seconds in a day.
            ;;
        hour)
            local divider=3600 # Seconds in an hour.
            ;;
        minute)
            local divider=60 # Seconds in a minute.
            ;;
        *)
            log_fatal_and_exit "Unknown period '$period'" 1
            ;;
    esac

    local target_sequence_number=$(( $latest_sequence_number - ( $latest_epoch - $target_epoch ) / $divider - 1 ))
    log_debug "Calculated target sequence number: $target_sequence_number"

    # --- Binary search for the sequence file using the library function ---
    # The initial low bound is the calculated sequence number.
    local initial_low_bound=$((10#$target_sequence_number))  # Ensure low_bound is treated as decimal.
    local initial_high_bound=$((10#$latest_sequence_number)) # Ensure high_bound is treated as decimal.

    log_info "Starting binary search with bounds: [$initial_low_bound, $initial_high_bound]"

    local found_sequence_number
    found_sequence_number=$(perform_binary_search_for_sequence \
        "$effective_base_url" \
        "$target_epoch" \
        "$initial_low_bound" \
        "$initial_high_bound")

    if [ $? -ne 0 ]; then # Check return status of perform_binary_search_for_sequence
        # The search function itself would have printed an error if result_sequence_number was -1.
        # Or if it encountered a more critical error.
        log_fatal_and_exit "Binary search did not find a suitable sequence number for '$target_timestamp_str' at $effective_base_url" 1
    fi

    # If perform_binary_search_for_sequence returned 0, $found_sequence_number contains the result.
    if [ "$found_sequence_number" -eq -1 ] || [ -z "$found_sequence_number" ]; then
         # This case should ideally be caught by the return status check above,
         # but as a safeguard if the search function echoed -1 for some reason AND returned 0.
        log_fatal_and_exit "Binary search logic error or no sequence found for '$target_timestamp_str' at $effective_base_url" 1
    fi

    log_info "Binary search found sequence number: $found_sequence_number"

    # Before printing the final URL, one last check on its accessibility could be done
    local final_url
    final_url=$(get_sequence_file_url "$effective_base_url" "$found_sequence_number")
    if [ $? -eq 0 ] && check_url_accessibility "$final_url" 5 1; then # Shorter timeout/retry
        log_info "Final result URL: $final_url"
        echo "$final_url"
    else
        log_fatal_and_exit "The determined sequence file URL ($final_url) appears inaccessible or could not be generated." 1
    fi
    return 0
}

# --- Script Entry Point ---
# (The rest of the script: Argument Parsing, calls to validate_period,
#  parse_and_prepare_base_url, and finally find_state_file, remain unchanged
#  from the previous version where these were finalized.)

# --- Argument Parsing ---
user_provided_url=""
osm_like_structure="true" # Default value for osm-like behavior.

# Parse command-line arguments.
# This loop handles options (like --osm-like, -h, --log-level) and collects positional arguments.
declare -a positional_args=() # Array to store positional arguments.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --osm-like*)
        if [[ "$1" == "--osm-like" ]]; then
            osm_like_structure="true"
        else
            # Extract the value after '=' if present.
            osm_like_value="${1#*=}" # Extract value after '='
            if [[ "$osm_like_value" =~ ^(true|false)$ ]]; then
                osm_like_structure="$osm_like_value"
            else
                log_error "Invalid value for --osm-like. Must be 'true' or 'false'. Got: '$osm_like_value'."
                echo ""
                # Pass $0 to show_usage for correct script name display.
                DEFAULT_URL_FOR_USAGE="${DEFAULT_INPUT_URL}" show_usage "$0"
                exit 1
            fi
        fi
        shift # Move past argument=value
        ;;
        --log-level*)
        if [[ "$1" == "--log-level" ]]; then
            if [[ $# -lt 2 ]]; then
                # echo "Error: --log-level requires a value (debug, info, warn, error, fatal)" >&2
                log_error "--log-level requires a value (debug, info, warn, error, fatal)"
                exit 1
            fi
            shift # Move to the value
            log_level_value="$1"
        else
            # Extract the value after '=' if present.
            log_level_value="${1#*=}" # Extract value after '='
        fi

        if ! set_log_level "$log_level_value"; then
            exit 1
        fi
        shift # Move past argument or value
        ;;
        -v|--verbose)
        # Shortcut for debug level
        set_log_level "debug"
        shift
        ;;
        -q|--quiet)
        # Shortcut for error level only
        set_log_level "error"
        shift
        ;;
        -h|--help)
        DEFAULT_URL_FOR_USAGE="${DEFAULT_INPUT_URL}" show_usage "$0"
        exit 0
        ;;
        -*) # Unknown option
        log_error "Unknown option: $1"
        echo ""
        DEFAULT_URL_FOR_USAGE="${DEFAULT_INPUT_URL}" show_usage "$0"
        exit 1
        ;;
        *) # Positional argument
        positional_args+=("$1")
        shift # Move past argument
        ;;
    esac
done
# Restore positional arguments for further processing.
set -- "${positional_args[@]}"

log_debug "Script started with log level: $LOG_LEVEL"
log_debug "Positional arguments: ${positional_args[*]}"

# Assign positional arguments after options have been processed.
if [ ${#positional_args[@]} -lt 2 ]; then
    log_error "Expected at least 2 positional arguments: <period> and <timestamp>."
    echo ""
    DEFAULT_URL_FOR_USAGE="${DEFAULT_INPUT_URL}" show_usage "$0"
    exit 1
fi

arg_period="${positional_args[0]}"
arg_timestamp="${positional_args[1]}"

if [ ${#positional_args[@]} -ge 3 ]; then
    user_provided_url="${positional_args[2]}"
else
    user_provided_url="$DEFAULT_INPUT_URL"
fi

log_info "Script parameters - Period: $arg_period, Timestamp: $arg_timestamp"
log_info "Using URL: $user_provided_url"
log_debug "OSM-like structure: $osm_like_structure"

# Validate the period argument.
# VALID_PERIODS_LIST is used by validate_period from lib/validation_.sh
validate_period "$arg_period" || exit 1 # validate_period prints its own error.

# Generate the effective base URL using the parsed arguments.
# This URL points directly to the directory where state.txt and sequence folders are expected.
log_info "Parsing and preparing base URL"
effective_base_url=$(parse_and_prepare_base_url "$user_provided_url" "$arg_period" "$osm_like_structure")
if [ $? -ne 0 ] || [ -z "$effective_base_url" ]; then # Check return status and if URL is empty
    log_fatal_and_exit "Could not determine a valid base URL from '$user_provided_url'." 1
fi

log_info "Effective base URL: $effective_base_url"

# Call the main function to find and output the state file URL.
find_state_file "$effective_base_url" "$arg_timestamp" "$arg_period"
# The exit status of find_state_file will be the script's exit status
# due to 'set -e' or if find_state_file uses 'exit'.
