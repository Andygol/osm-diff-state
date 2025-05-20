#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Define the directory where library scripts are located.
LIB_DIR="$(dirname "$0")/lib"
# Fallback if script is run from a different working directory where dirname "$0" is "."
[ ! -d "$LIB_DIR" ] && LIB_DIR="./lib"

# Source helper functions.
# Ensure these files exist in the LIB_DIR.
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

    # Construct URL for the current (latest) state.txt for the given period/data source.
    local current_period_state_txt_url="${effective_base_url%/}/state.txt"

    # Check either effective_base_url or current_period_state_txt_url for accessibility.
    # This is a more general check, as the state.txt might not exist but the base URL is valid.
    if ! check_url_accessibility "$effective_base_url"; then
        # Error message is printed by check_url_accessibility
        exit 1
    fi
    # If the above passes, state.txt itself might still be missing,
    # but at least the server/path is generally responsive.

    local latest_sequence_number
    latest_sequence_number=$(get_state_param "$current_period_state_txt_url" "sequenceNumber") || {
        echo "Error: Failed to get current 'sequenceNumber' from $current_period_state_txt_url" >&2
        echo "       This could be due to a missing state.txt, network issues not caught by the initial check, or incorrect URL." >&2
        exit 1
    }

    local latest_timestamp_str
    latest_timestamp_str=$(get_state_param "$current_period_state_txt_url" "timestamp") || {
        echo "Error: Failed to get current 'timestamp' from $current_period_state_txt_url" >&2
        exit 1
    }

    local latest_epoch
    latest_epoch=$(to_epoch "$latest_timestamp_str") || exit 1 # Convert latest state's time to epoch.

    local target_epoch
    target_epoch=$(to_epoch "$target_timestamp_str") || exit 1 # Convert target time to epoch; exit on failure.

    # echo "DEBUG: target_timestamp_str='$target_timestamp_str', target_epoch=$target_epoch"
    # echo "DEBUG: latest_timestamp_str='$latest_timestamp_str', latest_epoch=$latest_epoch"

    # Check if the target timestamp is in the future compared to the latest available state.
    if [ "$target_epoch" -gt "$latest_epoch" ]; then
        echo "Warning: Requested time '$target_timestamp_str' is in the future. Using latest available state ('$latest_timestamp_str')." >&2
        # Check accessibility of the specific sequence file URL before printing
        local latest_seq_url
        latest_seq_url=$(get_sequence_file_url "$effective_base_url" "$latest_sequence_number")
        if [ $? -eq 0 ] && check_url_accessibility "$latest_seq_url" 5 1; then # Shorter timeout/retry for this specific file
             echo "$latest_seq_url"
        else
            echo "Error: Latest sequence file URL ($latest_seq_url) appears inaccessible or could not be generated." >&2
            # Fallback or error further? For now, error.
            exit 1
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
            echo "Error (finding divider): Unknown period '$period'" >&2
            exit 1
            ;;
    esac

    local target_sequence_number=$(( $latest_sequence_number - ( $latest_epoch - $target_epoch ) / $divider - 1 ))

    # --- Binary search for the sequence file using the library function ---
    # The initial low bound is the calculated sequence number.
    local initial_low_bound=$((10#$target_sequence_number))  # Ensure low_bound is treated as decimal.
    local initial_high_bound=$((10#$latest_sequence_number)) # Ensure high_bound is treated as decimal.

    local found_sequence_number
    found_sequence_number=$(perform_binary_search_for_sequence \
        "$effective_base_url" \
        "$target_epoch" \
        "$initial_low_bound" \
        "$initial_high_bound")

    if [ $? -ne 0 ]; then # Check return status of perform_binary_search_for_sequence
        # The search function itself would have printed an error if result_sequence_number was -1.
        # Or if it encountered a more critical error.
        echo "Error: Binary search did not find a suitable sequence number for '$target_timestamp_str' at $effective_base_url" >&2
        exit 1
    fi

    # If perform_binary_search_for_sequence returned 0, $found_sequence_number contains the result.
    if [ "$found_sequence_number" -eq -1 ] || [ -z "$found_sequence_number" ]; then
         # This case should ideally be caught by the return status check above,
         # but as a safeguard if the search function echoed -1 for some reason AND returned 0.
        echo "Error: Binary search logic error or no sequence found for '$target_timestamp_str' at $effective_base_url" >&2
        exit 1
    fi

    # Before printing the final URL, one last check on its accessibility could be done
    local final_url
    final_url=$(get_sequence_file_url "$effective_base_url" "$found_sequence_number")
    if [ $? -eq 0 ] && check_url_accessibility "$final_url" 5 1; then # Shorter timeout/retry
        echo "$final_url"
    else
        echo "Error: The determined sequence file URL ($final_url) appears inaccessible or could not be generated." >&2
        exit 1
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
# This loop handles options (like --osm-like, -h) and collects positional arguments.
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
                echo -e "Error: Invalid value for --osm-like. Must be 'true' or 'false'. Got: '$osm_like_value'\n" >&2
                # Pass $0 to show_usage for correct script name display.
                DEFAULT_URL_FOR_USAGE="${DEFAULT_INPUT_URL}" show_usage "$0"
                exit 1
            fi
        fi
        shift # Move past argument=value
        ;;
        -h|--help)
        DEFAULT_URL_FOR_USAGE="${DEFAULT_INPUT_URL}" show_usage "$0"
        exit 0
        ;;
        -*) # Unknown option
        echo -e "Error: Unknown option: $1\n" >&2
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


# Assign positional arguments after options have been processed.
if [ ${#positional_args[@]} -lt 2 ]; then
    echo -e "Error: Missing required arguments: <period> and <timestamp>.\n" >&2
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

# Validate the period argument.
# VALID_PERIODS_LIST is used by validate_period from lib/validation_.sh
validate_period "$arg_period" || exit 1 # validate_period prints its own error.

# Generate the effective base URL using the parsed arguments.
# This URL points directly to the directory where state.txt and sequence folders are expected.
effective_base_url=$(parse_and_prepare_base_url "$user_provided_url" "$arg_period" "$osm_like_structure")
if [ $? -ne 0 ] || [ -z "$effective_base_url" ]; then # Check return status and if URL is empty
    echo "Error: Could not determine a valid base URL from '$user_provided_url'." >&2
    exit 1
fi

# Debugging output (can be commented out for production).
# echo "--- Debug Info ---"
# echo "  User Input URL: $user_provided_url"
# echo "  Period: $arg_period"
# echo "  Timestamp: $arg_timestamp"
# echo "  OSM-like: $osm_like_structure"
# echo "  Effective Base URL for Operations: $effective_base_url"
# echo "--------------------"

# Call the main function to find and output the state file URL.
find_state_file "$effective_base_url" "$arg_timestamp" "$arg_period"
# The exit status of find_state_file will be the script's exit status
# due to 'set -e' or if find_state_file uses 'exit'.
