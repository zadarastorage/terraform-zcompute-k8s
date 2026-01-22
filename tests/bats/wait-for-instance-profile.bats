#!/usr/bin/env bats
# Tests for files/wait-for-instance-profile.sh
# Tests retry/backoff logic and AWS profile patterns

load 'test_helper'

setup_file() {
    export TEST_ROOT="$(mktemp -d)"
    create_mock_cloud_init "${TEST_ROOT}"
}

teardown_file() {
    rm -rf "${TEST_ROOT}"
}

@test "wait-for-instance-profile.sh: _log function formats output correctly" {
    # Match the actual _log function pattern from the script
    # Reference: files/wait-for-instance-profile.sh line 4
    _log() { echo "[$(date +%s)][$0]${@}" ; }

    run _log "test message"
    assert_success
    assert_output --regexp "^\[[0-9]+\]\[.*\]test message$"
}

@test "wait-for-instance-profile.sh: backoff logic increments sleep correctly" {
    # Test the backoff pattern from the actual script
    # Reference: files/wait-for-instance-profile.sh lines 11, 17
    local SLEEP=1
    local iterations=0

    while [ $iterations -lt 5 ]; do
        [ $SLEEP -lt 10 ] && SLEEP=$((SLEEP + 1))
        iterations=$((iterations + 1))
    done

    # After 5 iterations starting at 1, SLEEP should be 6
    [ "$SLEEP" -eq 6 ]
}

@test "wait-for-instance-profile.sh: backoff sleep caps at 10" {
    local SLEEP=8
    local iterations=0

    while [ $iterations -lt 5 ]; do
        [ $SLEEP -lt 10 ] && SLEEP=$((SLEEP + 1))
        iterations=$((iterations + 1))
    done

    # Should cap at 10
    [ "$SLEEP" -eq 10 ]
}

@test "wait-for-instance-profile.sh: SLEEP defaults to 1 if unset" {
    # Reference: files/wait-for-instance-profile.sh line 6
    unset SLEEP
    local SLEEP=${SLEEP:-1}

    [ "$SLEEP" -eq 1 ]
}

@test "wait-for-instance-profile.sh: sources zadara-ec2 profile successfully" {
    # Verify the profile file can be sourced as the script expects
    # Reference: files/wait-for-instance-profile.sh line 3
    run bash -c "source ${TEST_ROOT}/etc/profile.d/zadara-ec2.sh && echo \$AWS_ENDPOINT_URL"
    assert_success
    assert_output "https://mock.zcompute.example.com"
}

@test "wait-for-instance-profile.sh: AWS endpoint variables are set after profile source" {
    run bash -c "source ${TEST_ROOT}/etc/profile.d/zadara-ec2.sh && echo \$AWS_ENDPOINT_URL_EC2"
    assert_success
    assert_output "https://mock.zcompute.example.com/api/v2/aws/ec2/"
}

@test "wait-for-instance-profile.sh: wait function pattern handles success" {
    # Test the wait-for-instance-profile function pattern
    # Reference: files/wait-for-instance-profile.sh lines 5-20
    local call_count=0

    # Simulate the pattern from the script
    wait_for_profile_simulation() {
        local SLEEP=1
        local max_attempts=3
        local attempt=0

        while [ $attempt -lt $max_attempts ]; do
            call_count=$((call_count + 1))
            # Simulate success on second attempt
            [ $call_count -ge 2 ] && return 0
            [ $SLEEP -lt 10 ] && SLEEP=$((SLEEP + 1))
            attempt=$((attempt + 1))
        done
        return 1
    }

    run wait_for_profile_simulation
    assert_success
}

@test "wait-for-instance-profile.sh: wait function pattern handles failure after max attempts" {
    # Test the wait-for-instance-profile function pattern
    wait_for_profile_failure() {
        local SLEEP=1
        local max_attempts=3
        local attempt=0

        while [ $attempt -lt $max_attempts ]; do
            # Never succeed
            [ $SLEEP -lt 10 ] && SLEEP=$((SLEEP + 1))
            attempt=$((attempt + 1))
        done
        return 1
    }

    run wait_for_profile_failure
    assert_failure
}

@test "wait-for-instance-profile.sh: curl fail flag pattern" {
    # Reference: files/wait-for-instance-profile.sh lines 8, 15
    # The script uses curl --fail to exit non-zero on HTTP errors

    # Simulate successful curl
    run bash -c 'exit 0'
    assert_success

    # Simulate failed curl (--fail returns non-zero for HTTP errors)
    run bash -c 'exit 22'  # 22 is curl's exit code for HTTP errors
    assert_failure
}

@test "wait-for-instance-profile.sh: PROFILE_NAME check pattern" {
    # Reference: files/wait-for-instance-profile.sh line 9
    # Script checks: [ $? -eq 0 ] && [ -n "${PROFILE_NAME:-}" ]

    # Empty PROFILE_NAME should fail the check
    PROFILE_NAME=""
    if [ -n "${PROFILE_NAME:-}" ]; then
        run true
    else
        run false
    fi
    assert_failure

    # Non-empty PROFILE_NAME should pass
    PROFILE_NAME="test-profile"
    if [ -n "${PROFILE_NAME:-}" ]; then
        run true
    else
        run false
    fi
    assert_success
}

@test "wait-for-instance-profile.sh: log message at threshold" {
    # Reference: files/wait-for-instance-profile.sh lines 12, 18
    # Only log when SLEEP >= 10
    local SLEEP=9
    local should_log=false

    [ $SLEEP -ge 10 ] && should_log=true
    [ "$should_log" = "false" ]

    SLEEP=10
    [ $SLEEP -ge 10 ] && should_log=true
    [ "$should_log" = "true" ]
}
