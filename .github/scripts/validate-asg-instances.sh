#!/usr/bin/env bash
# Validate that ASG instances reach expected count.
#
# Required env vars:
#   EC2_ENDPOINT  - zCompute EC2 API endpoint URL
#   RUN_ID        - GitHub Actions run ID (tag filter)
#   GITHUB_STEP_SUMMARY - (set by Actions)
set -euo pipefail

EXPECTED_CONTROL=3
EXPECTED_WORKER=1

echo "Waiting for ASG instances (${EXPECTED_CONTROL} control + ${EXPECTED_WORKER} worker)..."

RETRY=0
MAX_RETRY=40  # 40 * 15s = 10 min
CONTROL_COUNT=0
WORKER_COUNT=0

while [ $RETRY -lt $MAX_RETRY ]; do
  # Query with server-side filters, then re-filter client-side with jq
  # to guard against zCompute tag filtering inconsistencies
  ALL_INSTANCES=$(aws ec2 describe-instances --no-verify-ssl \
    --endpoint-url "${EC2_ENDPOINT}" \
    --filters "Name=tag:run-id,Values=${RUN_ID}" \
              "Name=instance-state-name,Values=running" \
    --output json 2>/dev/null || echo '{"Reservations":[]}')

  CONTROL_COUNT=$(echo "$ALL_INSTANCES" | jq --arg run_id "${RUN_ID}" '
    [.Reservations[].Instances[]
     | select(.State.Name == "running")
     | select(any(.Tags[]?; .Key == "run-id" and .Value == $run_id))
     | select(any(.Tags[]?; .Key == "zadara.com/k8s/role" and .Value == "control"))
    ] | length')

  WORKER_COUNT=$(echo "$ALL_INSTANCES" | jq --arg run_id "${RUN_ID}" '
    [.Reservations[].Instances[]
     | select(.State.Name == "running")
     | select(any(.Tags[]?; .Key == "run-id" and .Value == $run_id))
     | select(any(.Tags[]?; .Key == "zadara.com/k8s/role" and .Value == "worker"))
    ] | length')

  echo "Attempt $((RETRY + 1))/$MAX_RETRY: Control=${CONTROL_COUNT}/${EXPECTED_CONTROL} Worker=${WORKER_COUNT}/${EXPECTED_WORKER}"

  if [ "$CONTROL_COUNT" -ge "$EXPECTED_CONTROL" ] && [ "$WORKER_COUNT" -ge "$EXPECTED_WORKER" ]; then
    echo "All expected ASG instances are running"
    break
  fi

  RETRY=$((RETRY + 1))
  sleep 15
done

if [ "$CONTROL_COUNT" -lt "$EXPECTED_CONTROL" ] || [ "$WORKER_COUNT" -lt "$EXPECTED_WORKER" ]; then
  echo "::error::ASG instances did not reach expected count within 10 minutes"
  echo "  Control: ${CONTROL_COUNT}/${EXPECTED_CONTROL}"
  echo "  Worker: ${WORKER_COUNT}/${EXPECTED_WORKER}"
  exit 1
fi

cat >> "$GITHUB_STEP_SUMMARY" << EOF
### ASG Instance Validation

| Role | Expected | Running |
|------|----------|---------|
| Control | ${EXPECTED_CONTROL} | ${CONTROL_COUNT} |
| Worker | ${EXPECTED_WORKER} | ${WORKER_COUNT} |
| **Total** | **$((EXPECTED_CONTROL + EXPECTED_WORKER))** | **$((CONTROL_COUNT + WORKER_COUNT))** |

All ASG instances launched successfully.
EOF
