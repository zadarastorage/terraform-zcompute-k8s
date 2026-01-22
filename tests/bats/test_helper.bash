#!/usr/bin/env bash
# Common test helpers for BATS tests

# Load BATS helper libraries
load '/opt/bats-support/load.bash'
load '/opt/bats-assert/load.bash'
load '/opt/bats-file/load.bash'

# Project root (from container mount)
export PROJECT_ROOT="/workspace"

# Create mock cloud-init environment for testing
# Usage: create_mock_cloud_init "/tmp/test-root"
create_mock_cloud_init() {
    local test_root="${1}"

    mkdir -p "${test_root}/etc/zadara"
    mkdir -p "${test_root}/etc/rancher/k3s"
    mkdir -p "${test_root}/etc/profile.d"
    mkdir -p "${test_root}/var/lib/rancher/k3s/agent/etc"
    mkdir -p "${test_root}/run/k3s"

    # Mock k8s.json configuration
    cat > "${test_root}/etc/zadara/k8s.json" << 'MOCK_CONFIG'
{
  "cluster_name": "test-cluster",
  "cluster_role": "control",
  "cluster_version": "1.31.2",
  "cluster_kapi": "test-kapi.example.com",
  "cluster_token": "test-token-minimum-16-chars",
  "feature_gates": ["enable-cloud-controller"],
  "node_labels": {"env": "test", "tier": "control"},
  "node_taints": {"node-role.kubernetes.io/control-plane": ":NoSchedule"}
}
MOCK_CONFIG

    # Mock zadara-ec2 profile (sourced by scripts)
    cat > "${test_root}/etc/profile.d/zadara-ec2.sh" << 'MOCK_PROFILE'
export AWS_ENDPOINT_URL="https://mock.zcompute.example.com"
export AWS_ENDPOINT_URL_EC2="${AWS_ENDPOINT_URL}/api/v2/aws/ec2/"
MOCK_PROFILE
}

# Create mock k8s_helm.json for helm tests
create_mock_helm_config() {
    local test_root="${1}"

    mkdir -p "${test_root}/etc/zadara"

    cat > "${test_root}/etc/zadara/k8s_helm.json" << 'MOCK_HELM'
{
  "aws-cloud-controller-manager": {
    "repository_name": "aws-cloud-controller-manager",
    "repository_url": "https://kubernetes.github.io/cloud-provider-aws",
    "chart": "aws-cloud-controller-manager",
    "version": "0.0.8",
    "namespace": "kube-system",
    "order": 1,
    "wait": true,
    "config": null
  }
}
MOCK_HELM
}

# Source a script file with safety wrappers
# Prevents script from executing main logic, only loads functions
# Usage: safe_source "/workspace/files/k3s/setup.sh"
safe_source() {
    local script_path="${1}"
    # Set flag that tests can check to skip main execution
    export BATS_TEST_MODE=1
    # Source in subshell-safe way
    source "${script_path}" 2>/dev/null || true
}
