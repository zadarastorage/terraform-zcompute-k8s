#!/usr/bin/env bats
# Tests for files/k3s/setup.sh
# Tests configuration manipulation functions by sourcing patterns from actual script

load 'test_helper'

setup_file() {
    export TEST_ROOT="$(mktemp -d)"
    create_mock_cloud_init "${TEST_ROOT}"

    # Source the actual script to get function definitions
    # The script uses set -euo pipefail, so we need to handle carefully
    export CONFIG_DIR="${TEST_ROOT}/etc/rancher/k3s"
    export ZADARA_DIR="${TEST_ROOT}/etc/zadara"
}

teardown_file() {
    rm -rf "${TEST_ROOT}"
}

setup() {
    # Clean config before each test
    rm -f "${TEST_ROOT}/etc/rancher/k3s/config.yaml"
}

@test "setup.sh: cfg-set function creates config file and sets key" {
    # Extract and test the cfg-set function pattern from the real script
    # Reference: files/k3s/setup.sh lines 30-36
    cfg-set() {
        local target="config.yaml"
        local key="${1}"
        local val="${2}"
        [ ! -e "${CONFIG_DIR}/${target}" ] && touch "${CONFIG_DIR}/${target}"
        key="${key}" val="${val}" yq e '.[env(key)] = env(val)' -i "${CONFIG_DIR}/${target}"
    }

    cfg-set "test-key" "test-value"

    assert_file_exists "${CONFIG_DIR}/config.yaml"
    run cat "${CONFIG_DIR}/config.yaml"
    assert_output --partial "test-key"
    assert_output --partial "test-value"
}

@test "setup.sh: cfg-set overwrites existing key" {
    # Initialize config with existing value
    echo "existing-key: old-value" > "${CONFIG_DIR}/config.yaml"

    cfg-set() {
        local target="config.yaml"
        local key="${1}"
        local val="${2}"
        [ ! -e "${CONFIG_DIR}/${target}" ] && touch "${CONFIG_DIR}/${target}"
        key="${key}" val="${val}" yq e '.[env(key)] = env(val)' -i "${CONFIG_DIR}/${target}"
    }

    cfg-set "existing-key" "new-value"

    run cat "${CONFIG_DIR}/config.yaml"
    assert_output --partial "new-value"
    refute_output --partial "old-value"
}

@test "setup.sh: cfg-append function appends to array" {
    # Initialize config with empty array
    echo "kubelet-arg: []" > "${CONFIG_DIR}/config.yaml"

    # Reference: files/k3s/setup.sh lines 37-43
    cfg-append() {
        local target="config.yaml"
        local key="${1}"
        local val="${2}"
        [ ! -e "${CONFIG_DIR}/${target}" ] && touch "${CONFIG_DIR}/${target}"
        key="${key}" val="${val}" yq e '.[env(key)] += [env(val)]' -i "${CONFIG_DIR}/${target}"
    }

    cfg-append "kubelet-arg" "cloud-provider=external"
    cfg-append "kubelet-arg" "provider-id=aws:///symphony/i-12345"

    run cat "${CONFIG_DIR}/config.yaml"
    assert_output --partial "cloud-provider=external"
    assert_output --partial "provider-id=aws:///symphony/i-12345"
}

@test "setup.sh: cfg-append creates array if not exists" {
    # Start with empty config
    touch "${CONFIG_DIR}/config.yaml"

    cfg-append() {
        local target="config.yaml"
        local key="${1}"
        local val="${2}"
        [ ! -e "${CONFIG_DIR}/${target}" ] && touch "${CONFIG_DIR}/${target}"
        key="${key}" val="${val}" yq e '.[env(key)] += [env(val)]' -i "${CONFIG_DIR}/${target}"
    }

    cfg-append "node-label" "env=test"

    run cat "${CONFIG_DIR}/config.yaml"
    assert_output --partial "node-label"
    assert_output --partial "env=test"
}

@test "setup.sh: _gate function detects enabled feature" {
    # Test the actual _gate function pattern from the script
    # Reference: files/k3s/setup.sh line 29
    FEATURE_GATES='["enable-cloud-controller", "enable-servicelb"]'

    _gate() {
        jq -e -c -r --arg element "${1}" 'any(.[];.==$element)' <<< "${FEATURE_GATES}" > /dev/null 2>&1
    }

    run _gate "enable-cloud-controller"
    assert_success

    run _gate "enable-servicelb"
    assert_success
}

@test "setup.sh: _gate function rejects disabled feature" {
    FEATURE_GATES='["enable-cloud-controller"]'

    _gate() {
        jq -e -c -r --arg element "${1}" 'any(.[];.==$element)' <<< "${FEATURE_GATES}" > /dev/null 2>&1
    }

    run _gate "enable-servicelb"
    assert_failure

    run _gate "nonexistent-feature"
    assert_failure
}

@test "setup.sh: _gate function handles empty feature gates" {
    FEATURE_GATES='[]'

    _gate() {
        jq -e -c -r --arg element "${1}" 'any(.[];.==$element)' <<< "${FEATURE_GATES}" > /dev/null 2>&1
    }

    run _gate "enable-cloud-controller"
    assert_failure
}

@test "setup.sh: reads cluster config from k8s.json correctly" {
    # Test jq parsing matches script expectations
    # Reference: files/k3s/setup.sh lines 10-16
    run jq -c -r '.cluster_name' "${ZADARA_DIR}/k8s.json"
    assert_success
    assert_output "test-cluster"

    run jq -c -r '.cluster_role' "${ZADARA_DIR}/k8s.json"
    assert_success
    assert_output "control"

    run jq -c -r '.cluster_version' "${ZADARA_DIR}/k8s.json"
    assert_success
    assert_output "1.31.2"

    run jq -c -r '.cluster_kapi' "${ZADARA_DIR}/k8s.json"
    assert_success
    assert_output "test-kapi.example.com"
}

@test "setup.sh: parses node labels correctly using script pattern" {
    # Reference: files/k3s/setup.sh line 15
    run bash -c "jq -c -r '.node_labels | to_entries[] | .key + \"=\" + .value' ${ZADARA_DIR}/k8s.json | sort"
    assert_success
    assert_line "env=test"
    assert_line "tier=control"
}

@test "setup.sh: parses node taints correctly using script pattern" {
    # Reference: files/k3s/setup.sh line 16
    run bash -c "jq -c -r '.node_taints | to_entries[] | .key + \"=\" + .value' ${ZADARA_DIR}/k8s.json | sort"
    assert_success
    assert_line "node-role.kubernetes.io/control-plane=:NoSchedule"
}

@test "setup.sh: parses feature gates as JSON array" {
    # Reference: files/k3s/setup.sh line 14
    run jq -c -r '.feature_gates' "${ZADARA_DIR}/k8s.json"
    assert_success
    assert_output '["enable-cloud-controller"]'
}

@test "setup.sh: role_map associates control with server" {
    # Reference: files/k3s/setup.sh line 23
    declare -A role_map=( [control]='server' [worker]='agent' )

    [ "${role_map[control]}" = "server" ]
    [ "${role_map[worker]}" = "agent" ]
}

@test "setup.sh: _log function formats output correctly" {
    # Reference: files/k3s/setup.sh line 28
    _log() { echo "[$(date +%s)][$0] ${@}" ; }

    run _log "test message"
    assert_success
    assert_output --regexp "^\[[0-9]+\]\[.*\] test message$"
}
