#!/bin/bash
# etcd-backup-test.sh - Test orchestration for etcd backup/restore lifecycle
#
# This script manages the backup/restore test flow:
# 1. Create sentinel data (ConfigMap) in the cluster
# 2. Wait for etcd write consistency
# 3. Trigger manual etcd snapshot to S3
# 4. Verify snapshot upload to S3
#
# The full restore verification (destroy + recreate + verify sentinel) is
# handled by the workflow, not this script.
#
# Required environment variables:
#   BASTION_IP       - Public IP of bastion host
#   CONTROL_IP       - Private IP of control plane node
#   GARAGE_IP        - Private IP of GarageHQ instance
#   GARAGE_BUCKET    - S3 bucket name
#   GARAGE_ACCESS_KEY - S3 access key
#   GARAGE_SECRET_KEY - S3 secret key
#   RUN_ID           - GitHub Actions run ID
#   COMMIT_SHA       - Git commit SHA
#   SSH_KEY          - Path to SSH private key (default: /tmp/bastion_ssh_key)
#
set -euo pipefail

# --- Environment Validation ---

: "${BASTION_IP:?Required: BASTION_IP}"
: "${CONTROL_IP:?Required: CONTROL_IP}"
: "${GARAGE_IP:?Required: GARAGE_IP}"
: "${GARAGE_BUCKET:?Required: GARAGE_BUCKET}"
: "${GARAGE_ACCESS_KEY:?Required: GARAGE_ACCESS_KEY}"
: "${GARAGE_SECRET_KEY:?Required: GARAGE_SECRET_KEY}"
: "${RUN_ID:?Required: RUN_ID}"
: "${COMMIT_SHA:?Required: COMMIT_SHA}"
: "${SSH_KEY:=/tmp/bastion_ssh_key}"

# --- Constants ---

OUTPUT_FILE="/tmp/etcd-backup-test-results.json"
NAMESPACE="etcd-test"
CONFIGMAP_NAME="backup-sentinel"
SNAPSHOT_NAME="backup-test-${RUN_ID}"
SETTLE_TIME_SECONDS=30
S3_VERIFY_TIMEOUT_SECONDS=60

# --- Initialize JSON Output ---

echo '{"results":{"tool":{"name":"etcd-backup-test","version":"1.0.0"},"summary":{"tests":0,"passed":0,"failed":0},"tests":[]}}' > "${OUTPUT_FILE}"

# --- Helper Functions ---

log() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"
}

log_stage() {
  local name="$1"
  local status="$2"
  local duration="$3"
  local message="${4:-}"

  # Update test array
  jq --arg name "${name}" \
     --arg status "${status}" \
     --argjson duration "${duration}" \
     --arg message "${message}" \
     '.results.tests += [{"name":$name,"status":$status,"duration":$duration,"message":$message}]' \
     "${OUTPUT_FILE}" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "${OUTPUT_FILE}"

  # Update summary counts
  jq '.results.summary.tests = (.results.tests | length)' \
     "${OUTPUT_FILE}" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "${OUTPUT_FILE}"
  jq '.results.summary.passed = ([.results.tests[] | select(.status=="passed")] | length)' \
     "${OUTPUT_FILE}" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "${OUTPUT_FILE}"
  jq '.results.summary.failed = ([.results.tests[] | select(.status=="failed")] | length)' \
     "${OUTPUT_FILE}" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "${OUTPUT_FILE}"
}

run_stage() {
  local name="$1"
  shift
  local start_time
  local end_time
  local duration
  local status
  local output

  log "Starting stage: ${name}"
  start_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))

  if output=$("$@" 2>&1); then
    status="passed"
    log "Stage ${name}: PASSED"
  else
    status="failed"
    log "Stage ${name}: FAILED"
    log "Output: ${output}"
  fi

  end_time=$(date +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
  duration=$((end_time - start_time))

  log_stage "${name}" "${status}" "${duration}" "${output:-}"

  if [ "${status}" == "failed" ]; then
    return 1
  fi
  return 0
}

bastion_ssh() {
  ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o LogLevel=ERROR \
      -i "${SSH_KEY}" \
      "ubuntu@${BASTION_IP}" \
      "$@"
}

bastion_kubectl() {
  bastion_ssh kubectl "$@"
}

control_ssh() {
  ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o LogLevel=ERROR \
      -i "${SSH_KEY}" \
      -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i ${SSH_KEY} -W %h:%p ubuntu@${BASTION_IP}" \
      "ubuntu@${CONTROL_IP}" \
      "$@"
}

# --- Stage Implementations ---

create_sentinel() {
  log "Creating namespace ${NAMESPACE} and ConfigMap ${CONFIGMAP_NAME}"

  # Create namespace (idempotent)
  bastion_kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | bastion_kubectl apply -f -

  # Create ConfigMap with sentinel data
  bastion_kubectl create configmap "${CONFIGMAP_NAME}" \
    --namespace="${NAMESPACE}" \
    --from-literal=run-id="${RUN_ID}" \
    --from-literal=timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --from-literal=commit-sha="${COMMIT_SHA}" \
    --dry-run=client -o yaml | bastion_kubectl apply -f -

  # Verify creation
  bastion_kubectl get configmap "${CONFIGMAP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.data.run-id}'
}

settle_time() {
  log "Waiting ${SETTLE_TIME_SECONDS} seconds for etcd write consistency"
  sleep "${SETTLE_TIME_SECONDS}"
  log "Settle time complete"
}

trigger_backup() {
  log "Triggering etcd snapshot: ${SNAPSHOT_NAME}"

  # Run k3s etcd-snapshot save on control plane
  control_ssh "sudo k3s etcd-snapshot save --name ${SNAPSHOT_NAME}"

  log "Snapshot command completed"
}

verify_s3_upload() {
  log "Verifying snapshot upload to S3 bucket: ${GARAGE_BUCKET}"

  local elapsed=0
  local found=false

  while [ "${elapsed}" -lt "${S3_VERIFY_TIMEOUT_SECONDS}" ]; do
    # List objects in bucket and check for snapshot
    if bastion_ssh "AWS_ACCESS_KEY_ID='${GARAGE_ACCESS_KEY}' AWS_SECRET_ACCESS_KEY='${GARAGE_SECRET_KEY}' aws s3api list-objects-v2 --endpoint-url 'http://${GARAGE_IP}:3900' --bucket '${GARAGE_BUCKET}' 2>/dev/null" | grep -q "${SNAPSHOT_NAME}"; then
      found=true
      break
    fi

    log "Snapshot not yet found, waiting... (${elapsed}s / ${S3_VERIFY_TIMEOUT_SECONDS}s)"
    sleep 5
    elapsed=$((elapsed + 5))
  done

  if [ "${found}" == "true" ]; then
    log "Snapshot found in S3 bucket"
    return 0
  else
    log "ERROR: Snapshot not found in S3 bucket after ${S3_VERIFY_TIMEOUT_SECONDS}s"
    return 1
  fi
}

verify_sentinel() {
  log "Verifying sentinel ConfigMap exists with correct data"

  local expected_run_id="${RUN_ID}"
  local expected_commit_sha="${COMMIT_SHA}"

  # Get ConfigMap data
  local cm_data
  cm_data=$(bastion_kubectl get configmap "${CONFIGMAP_NAME}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.data}' 2>/dev/null) || {
    log "ERROR: ConfigMap not found"
    return 1
  }

  if [ -z "${cm_data}" ]; then
    log "ERROR: ConfigMap data is empty"
    return 1
  fi

  # Verify run-id
  local actual_run_id
  actual_run_id=$(echo "${cm_data}" | jq -r '.["run-id"]')
  if [ "${actual_run_id}" != "${expected_run_id}" ]; then
    log "ERROR: run-id mismatch: expected=${expected_run_id}, actual=${actual_run_id}"
    return 1
  fi

  # Verify commit-sha
  local actual_sha
  actual_sha=$(echo "${cm_data}" | jq -r '.["commit-sha"]')
  if [ "${actual_sha}" != "${expected_commit_sha}" ]; then
    log "ERROR: commit-sha mismatch: expected=${expected_commit_sha}, actual=${actual_sha}"
    return 1
  fi

  log "Sentinel verification passed"
  return 0
}

# --- GitHub Step Summary ---

write_summary() {
  if [ -z "${GITHUB_STEP_SUMMARY:-}" ]; then
    log "GITHUB_STEP_SUMMARY not set, skipping summary write"
    return 0
  fi

  {
    echo "## etcd Backup/Restore Test Results"
    echo ""
    echo "**Run ID:** ${RUN_ID}"
    echo "**Commit:** ${COMMIT_SHA}"
    echo ""
    echo "| Stage | Status | Duration |"
    echo "|-------|--------|----------|"
    jq -r '.results.tests[] | "| \(.name) | \(if .status == "passed" then "PASS" else "FAIL" end) | \(.duration)ms |"' "${OUTPUT_FILE}"
    echo ""

    local failed
    failed=$(jq '[.results.tests[] | select(.status=="failed")] | length' "${OUTPUT_FILE}")
    if [ "${failed}" -eq 0 ]; then
      echo "**Result:** All stages passed"
    else
      echo "**Result:** ${failed} stage(s) failed"
    fi
  } >> "$GITHUB_STEP_SUMMARY"

  log "Summary written to GITHUB_STEP_SUMMARY"
}

# --- Main Execution ---

main() {
  local mode="${1:-backup}"

  log "Starting etcd backup test (mode: ${mode})"
  log "Run ID: ${RUN_ID}"
  log "Commit SHA: ${COMMIT_SHA}"
  log "Bastion IP: ${BASTION_IP}"
  log "Control IP: ${CONTROL_IP}"
  log "Garage IP: ${GARAGE_IP}"
  log "Garage Bucket: ${GARAGE_BUCKET}"

  local failed=0

  case "${mode}" in
    backup)
      # Backup stages: create sentinel, settle, trigger backup, verify S3
      run_stage "create-sentinel" create_sentinel || failed=1
      run_stage "settle-time" settle_time || failed=1
      run_stage "trigger-backup" trigger_backup || failed=1
      run_stage "verify-s3-upload" verify_s3_upload || failed=1
      ;;
    verify)
      # Verify stage: check sentinel after restore
      run_stage "verify-sentinel" verify_sentinel || failed=1
      ;;
    full)
      # Full test: all stages (backup + verify, destroy/recreate handled externally)
      run_stage "create-sentinel" create_sentinel || failed=1
      run_stage "settle-time" settle_time || failed=1
      run_stage "trigger-backup" trigger_backup || failed=1
      run_stage "verify-s3-upload" verify_s3_upload || failed=1
      ;;
    *)
      log "ERROR: Unknown mode: ${mode}"
      log "Usage: $0 [backup|verify|full]"
      exit 1
      ;;
  esac

  write_summary

  log "Test results written to: ${OUTPUT_FILE}"

  if [ "${failed}" -eq 1 ]; then
    log "Test FAILED"
    exit 1
  fi

  log "Test PASSED"
  exit 0
}

main "$@"
