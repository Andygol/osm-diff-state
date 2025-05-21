#!/bin/bash
source "$(dirname "$0")/../lib/validation_.sh"

test_validate_period() {
    echo "Running: test_validate_period"
    if validate_period "hour"; then
        echo "PASS: validate_period 'hour'"
    else
        echo "FAIL: validate_period 'hour'"
        return 1
    fi

    if ! validate_period "invalid_period" >/dev/null 2>&1; then
        echo "PASS: validate_period 'invalid_period' correctly failed"
    else
        echo "FAIL: validate_period 'invalid_period' should have passed"
        return 1
    fi
}

test_validate_period
if [ $? -eq 0 ]; then
    echo "All validation_ functions tests passed."
else
    echo "Some validation_ functions tests failed."
    exit 1
fi
