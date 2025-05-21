#!/bin/bash

# Fetches content from a URL and extracts a named parameter's value.
# Assumes parameters are in 'key=value' format, one per line.
# Arguments:
#   $1 - The URL to fetch.
#   $2 - The name of the parameter to extract (e.g., "sequenceNumber", "timestamp").
# Output:
#   Prints the extracted parameter value to stdout.
# Returns:
#   0 on success, 1 on failure (e.g., failed to fetch, parameter not found).
get_state_param() {
    local url_to_fetch="$1"
    local param_name="$2"
    local http_content
    local param_value

    # Fetch content using wget, suppressing output, allowing redirects.
    http_content=$(wget --max-redirect=5 -q -O - "$url_to_fetch" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Error (get_state_param): Failed to fetch $url_to_fetch" >&2
        return 1
    fi

    # Extract the parameter value.
    # grep for lines starting with "param_name=", then cut by '=' and get the 2nd field.
    # sed removes any backslashes (used for escaping in state.txt) and trailing 'Z'.
    # tr removes carriage returns and newlines.
    param_value=$(echo "$http_content" | grep "^${param_name}=" | cut -d'=' -f2 | sed 's/\\//g; s/Z$//' | tr -d '\r\n ')

    # Check if the parameter was actually found and has a value.
    if [ -z "$param_value" ]; then
      # This check is important because grep might not find the line,
      # or the value might legitimately be empty after processing.
      # echo "Debug (get_state_param): Parameter '$param_name' not found or empty in $url_to_fetch" >&2
      return 1 # Parameter not found or empty
    fi

    echo "$param_value"
    return 0
}

# Generates the full URL for a specific OpenStreetMap replication sequence state file.
# Arguments:
#   $1: effective_base_url - The base URL of the directory containing sequence files.
#                            (e.g., "https://planet.osm.org/replication/hour/" or "https://custom.com/data/")
#   $2: sequence_number - The sequence number.
# Output:
#   Prints the full URL to the sequence state file to stdout.
# Returns:
#   0 on success, 1 if sequence_number is not an integer.
get_sequence_file_url() {
    local effective_base_url="$1" # e.g., https://planet.osm.org/replication/hour/ or https://custom.com/data/
    local sequence_number="$2"
    local padded_sequence_number

    # Validate that sequence_number is an integer.
    if ! [[ "$sequence_number" =~ ^[0-9]+$ ]]; then
        echo "Error (get_sequence_file_url): Sequence number must be an integer. Got: '$sequence_number'" >&2
        return 1
    fi

    # Format the sequence number to a 9-digit string, zero-padded.
    padded_sequence_number=$(printf "%09d" "$sequence_number")

    # Construct the path segments (e.g., 000/001/234).
    # Remove a trailing slash from effective_base_url if present, before appending path.
    echo "${effective_base_url%/}/${padded_sequence_number:0:3}/${padded_sequence_number:3:3}/${padded_sequence_number:6:3}.state.txt"
    return 0
}
