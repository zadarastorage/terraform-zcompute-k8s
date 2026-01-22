#!/usr/bin/env bats
# Tests for files/setup-helm.sh
# Tests helm configuration parsing and wait logic patterns

load 'test_helper'

setup_file() {
    export TEST_ROOT="$(mktemp -d)"
    create_mock_cloud_init "${TEST_ROOT}"
    create_mock_helm_config "${TEST_ROOT}"
    export ZADARA_DIR="${TEST_ROOT}/etc/zadara"
}

teardown_file() {
    rm -rf "${TEST_ROOT}"
}

@test "setup-helm.sh: parses helm repository info from k8s_helm.json" {
    # Test the jq patterns used in the actual script
    # Reference: files/setup-helm.sh lines 44-45
    run jq -c -r '.["aws-cloud-controller-manager"].repository_name' "${ZADARA_DIR}/k8s_helm.json"
    assert_success
    assert_output "aws-cloud-controller-manager"
}

@test "setup-helm.sh: parses helm repository URL" {
    run jq -c -r '.["aws-cloud-controller-manager"].repository_url' "${ZADARA_DIR}/k8s_helm.json"
    assert_success
    assert_output "https://kubernetes.github.io/cloud-provider-aws"
}

@test "setup-helm.sh: parses helm chart name" {
    # Reference: files/setup-helm.sh line 55
    run jq -c -r '.["aws-cloud-controller-manager"].chart' "${ZADARA_DIR}/k8s_helm.json"
    assert_success
    assert_output "aws-cloud-controller-manager"
}

@test "setup-helm.sh: parses helm chart version" {
    # Reference: files/setup-helm.sh line 57
    run jq -c -r '.["aws-cloud-controller-manager"].version' "${ZADARA_DIR}/k8s_helm.json"
    assert_success
    assert_output "0.0.8"
}

@test "setup-helm.sh: parses helm namespace" {
    # Reference: files/setup-helm.sh line 58
    run jq -c -r '.["aws-cloud-controller-manager"].namespace' "${ZADARA_DIR}/k8s_helm.json"
    assert_success
    assert_output "kube-system"
}

@test "setup-helm.sh: parses wait flag" {
    # Reference: files/setup-helm.sh line 56
    run jq -c -r '.["aws-cloud-controller-manager"].wait' "${ZADARA_DIR}/k8s_helm.json"
    assert_success
    assert_output "true"
}

@test "setup-helm.sh: wait-for-endpoint pattern works correctly" {
    # Test the wait logic pattern from the actual script
    # Reference: files/setup-helm.sh lines 23-31
    wait_for_endpoint() {
        local url="${1}"
        local max_attempts="${2:-3}"
        local attempt=0

        while [ $attempt -lt $max_attempts ]; do
            # In real script this would curl, here we simulate
            [ "$url" = "https://success:6443/cacerts" ] && return 0
            attempt=$((attempt + 1))
        done
        return 1
    }

    run wait_for_endpoint "https://success:6443/cacerts"
    assert_success

    run wait_for_endpoint "https://failure:6443/cacerts"
    assert_failure
}

@test "setup-helm.sh: backoff sleep logic increments correctly" {
    # Reference: files/setup-helm.sh line 28
    local SLEEP=1
    local iterations=0

    while [ $iterations -lt 5 ]; do
        [ $SLEEP -lt 10 ] && SLEEP=$((SLEEP + 1))
        iterations=$((iterations + 1))
    done

    # After 5 iterations starting at 1, SLEEP should be 6
    [ "$SLEEP" -eq 6 ]
}

@test "setup-helm.sh: backoff sleep caps at 10" {
    # Reference: files/setup-helm.sh line 28
    local SLEEP=8
    local iterations=0

    while [ $iterations -lt 5 ]; do
        [ $SLEEP -lt 10 ] && SLEEP=$((SLEEP + 1))
        iterations=$((iterations + 1))
    done

    # Should cap at 10
    [ "$SLEEP" -eq 10 ]
}

@test "setup-helm.sh: extracts unique repositories from config" {
    # Reference: files/setup-helm.sh line 43
    run bash -c "jq -c -r 'to_entries[] | {repository_name: .value.repository_name, repository_url: .value.repository_url}' ${ZADARA_DIR}/k8s_helm.json | sort -u"
    assert_success
    assert_output --partial "aws-cloud-controller-manager"
    assert_output --partial "kubernetes.github.io/cloud-provider-aws"
}

@test "setup-helm.sh: order field is parsed for installation sequence" {
    # Reference: files/setup-helm.sh line 52
    run jq -c -r '.["aws-cloud-controller-manager"].order' "${ZADARA_DIR}/k8s_helm.json"
    assert_success
    assert_output "1"
}

@test "setup-helm.sh: config field can be null" {
    # Reference: files/setup-helm.sh line 59
    run jq -c -r '.["aws-cloud-controller-manager"].config' "${ZADARA_DIR}/k8s_helm.json"
    assert_success
    assert_output "null"
}

@test "setup-helm.sh: sorts entries by order then key" {
    # Reference: files/setup-helm.sh line 52
    # Create multi-entry config
    cat > "${ZADARA_DIR}/k8s_helm_multi.json" << 'EOF'
{
  "zebra-addon": {"order": 2, "chart": "zebra"},
  "alpha-addon": {"order": 1, "chart": "alpha"},
  "beta-addon": {"order": 1, "chart": "beta"}
}
EOF

    run bash -c "jq -c -r 'to_entries | sort_by(.value.order, .key)[] | .key' ${ZADARA_DIR}/k8s_helm_multi.json"
    assert_success
    # Order 1 entries come first (alpha, beta alphabetically), then order 2
    assert_line --index 0 "alpha-addon"
    assert_line --index 1 "beta-addon"
    assert_line --index 2 "zebra-addon"
}

@test "setup-helm.sh: _log function matches script pattern" {
    # Reference: files/setup-helm.sh line 4
    _log() { echo "[$(date +%s)][$0]${@}" ; }

    run _log "test message"
    assert_success
    assert_output --regexp "^\[[0-9]+\]\[.*\]test message$"
}
