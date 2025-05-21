#!/bin/bash

# Source the function to be tested
source "$(dirname "$0")/../lib/date_.sh"

# Test cases
test_to_epoch_valid() {
    echo "Running: test_to_epoch_valid"
    local expected="1672524000" # Epoch for 2023-01-01T00:00:00Z
    local actual
    actual=$(to_epoch "2023-01-01T00:00:00Z")
    if [[ "$actual" == "$expected" ]]; then
        echo "  PASS: to_epoch '2023-01-01T00:00:00Z' -> $actual"
    else
        echo "  FAIL: to_epoch '2023-01-01T00:00:00Z'. Expected $expected, got $actual"
        return 1
    fi

    expected=(1715817600 1715903999) # Epoch for 2024-05-16
    actual=$(to_epoch "2024-05-16") # Test YYYY-MM-DD
    if [ "$actual" -ge "${expected[0]}" ] && [ "$actual" -le "${expected[1]}" ]; then
        echo "  PASS: to_epoch '2024-05-16' -> $actual is between ${expected[0]} and ${expected[1]}"
    else
        echo "  FAIL: to_epoch '2024-05-16'. Expected $expected, got $actual"
        return 1
    fi

    # Add more valid cases for different formats
}

test_to_epoch_invalid() {
    echo -e "\n"
    echo "Running: test_to_epoch_invalid"
    if ! to_epoch "invalid-date-string" >/dev/null 2>&1; then
        echo "  PASS: to_epoch 'invalid-date-string' correctly failed"
    else
        echo "  FAIL: to_epoch 'invalid-date-string' should have failed"
        return 1
    fi
}

# Run tests
test_to_epoch_valid && test_to_epoch_invalid
echo -e "\n"

if [ $? -eq 0 ]; then
    echo "All date_ functions tests passed."
else
    echo "Some date_ functions tests failed."
    exit 1
fi
