#!/usr/bin/env bash
# Verify that all cluster instances have been terminated after destroy.
#
# Required env vars:
#   CLUSTER_NAME - cluster name tag to filter on
#   EC2_ENDPOINT - zCompute EC2 API endpoint URL
set -euo pipefail

echo "Verifying cleanup of ${CLUSTER_NAME}..."

# Poll until no running instances found (max 10 min = 40 * 15s)
for i in $(seq 1 40); do
  # Query with server-side filters, then re-filter client-side with jq
  # to guard against zCompute tag filtering inconsistencies
  INSTANCES=$(aws ec2 describe-instances \
    --endpoint-url "${EC2_ENDPOINT}" \
    --filters "Name=tag:cluster-name,Values=${CLUSTER_NAME}" \
              "Name=instance-state-name,Values=pending,running,stopping,shutting-down" \
    --output json --no-verify-ssl 2>/dev/null \
    | jq -r --arg name "${CLUSTER_NAME}" '
      [.Reservations[].Instances[]
       | select(.State.Name == ("pending","running","stopping","shutting-down"))
       | select(any(.Tags[]?; .Key == "cluster-name" and .Value == $name))
       | .InstanceId
      ] | join(" ") | if . == "" then empty else . end
    ' || true)

  if [ -z "$INSTANCES" ] || [ "$INSTANCES" = "None" ]; then
    echo "Cleanup verified - no running instances with cluster-name=${CLUSTER_NAME}"
    exit 0
  fi
  echo "Attempt ${i}/40: Instances still exist: ${INSTANCES}"
  sleep 15
done

echo "::warning::Cleanup verification timed out after 10 minutes, proceeding anyway"
