#!/usr/bin/env bats
# Tests for files/setup-os.sh
# Note: setup-os.sh is mostly imperative (package installs, downloads)
# These tests verify the testable logic: path detection, command checks

load 'test_helper'

@test "setup-os.sh: apt-get detection pattern works" {
    # Test the which-based detection pattern used in the script
    # Reference: files/setup-os.sh line 7
    if [ -x "$(which apt-get)" ]; then
        run which apt-get
        assert_success
    else
        skip "apt-get not available in test environment"
    fi
}

@test "setup-os.sh: yq is installed and correct version" {
    # The script installs yq v4.44.3 - verify it's available
    # Reference: files/setup-os.sh line 8
    run yq --version
    assert_success
    assert_output --partial "4.44"
}

@test "setup-os.sh: yq binary detection pattern" {
    # Reference: files/setup-os.sh line 8
    # Pattern: [ ! -x "$(which yq)" ]
    run which yq
    assert_success
    run test -x "$(which yq)"
    assert_success
}

@test "setup-os.sh: curl is available" {
    # Required by setup-os.sh for downloads
    run which curl
    assert_success
}

@test "setup-os.sh: jq is available" {
    # Required by scripts that process JSON
    run which jq
    assert_success
}

@test "setup-os.sh: CNI plugin directory structure is standard" {
    # setup-os.sh creates /opt/cni/bin
    # Reference: files/setup-os.sh line 24
    local cni_path="/opt/cni/bin"

    # Test that the path is valid and creatable
    run mkdir -p "${cni_path}"
    assert_success

    # Verify it exists
    run test -d "${cni_path}"
    assert_success

    # Cleanup
    rmdir "${cni_path}" 2>/dev/null || true
    rmdir /opt/cni 2>/dev/null || true
}

@test "setup-os.sh: which command returns executable path" {
    # Test the which pattern used throughout setup-os.sh
    run bash -c '[ -x "$(which bash)" ] && echo "found" || echo "not found"'
    assert_success
    assert_output "found"
}

@test "setup-os.sh: which command handles missing binary" {
    run bash -c '[ -x "$(which nonexistent-binary-12345)" ] && echo "found" || echo "not found"'
    assert_success
    assert_output "not found"
}

@test "setup-os.sh: file existence check pattern" {
    # Reference: files/setup-os.sh lines 14-15
    # Pattern: [ ! -e /path/to/file ] && wget ...

    local test_file="/tmp/bats-test-file-$$"

    # File doesn't exist - condition should be true
    run bash -c "[ ! -e ${test_file} ] && echo 'would download'"
    assert_success
    assert_output "would download"

    # Create file
    touch "${test_file}"

    # File exists - condition should be false
    run bash -c "[ ! -e ${test_file} ] && echo 'would download' || echo 'skip download'"
    assert_success
    assert_output "skip download"

    # Cleanup
    rm -f "${test_file}"
}

@test "setup-os.sh: chmod pattern for executables" {
    # Reference: files/setup-os.sh line 16
    local test_file="/tmp/bats-chmod-test-$$"

    # Create non-executable file
    echo "#!/bin/bash" > "${test_file}"
    chmod 644 "${test_file}"

    # Verify not executable
    run test -x "${test_file}"
    assert_failure

    # Apply chmod 755 (as script does)
    chmod 755 "${test_file}"

    # Verify now executable
    run test -x "${test_file}"
    assert_success

    # Cleanup
    rm -f "${test_file}"
}

@test "setup-os.sh: ufw disable pattern detection" {
    # Reference: files/setup-os.sh line 21
    # Pattern: [ -x "$(which ufw)" ] && ufw disable
    # This tests the detection, not the disable action

    # Test the pattern structure
    run bash -c '
        mock_ufw() { echo "mock ufw called"; }
        if [ -x "$(which ufw 2>/dev/null)" ]; then
            echo "ufw found"
        else
            echo "ufw not found"
        fi
    '
    assert_success
    # We expect "ufw not found" in the test container (no ufw installed)
    assert_output "ufw not found"
}

@test "setup-os.sh: tar extraction pattern works" {
    # Reference: files/setup-os.sh line 25
    # Pattern: tar -C /opt/cni/bin -xzf archive.tgz

    local test_dir="/tmp/bats-tar-test-$$"
    local test_archive="/tmp/bats-test-archive-$$.tgz"

    # Create test directory and archive
    mkdir -p "${test_dir}/subdir"
    echo "test content" > "${test_dir}/subdir/test.txt"
    tar -czf "${test_archive}" -C "${test_dir}" subdir

    # Create extraction target
    local extract_dir="/tmp/bats-extract-$$"
    mkdir -p "${extract_dir}"

    # Extract
    run tar -C "${extract_dir}" -xzf "${test_archive}"
    assert_success

    # Verify extraction
    run cat "${extract_dir}/subdir/test.txt"
    assert_success
    assert_output "test content"

    # Cleanup
    rm -rf "${test_dir}" "${extract_dir}" "${test_archive}"
}
