#!/usr/bin/env bash
# Validate that expected Helm releases are deployed on the cluster.
#
# Required env vars:
#   BASTION_IP  - public IP of the bastion host
#   CONTROL_IP  - private IP of a control plane node
#   SSH_KEY     - path to SSH private key
#   GITHUB_STEP_SUMMARY - (set by Actions)
set -euo pipefail

PROXY_CMD="ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} -W %h:%p ubuntu@${BASTION_IP}"

EXPECTED_RELEASES="zadara-aws-config traefik-elb aws-cloud-controller-manager flannel aws-ebs-csi-driver cluster-autoscaler aws-load-balancer-controller"
EXPECTED_COUNT=7

echo "Waiting for ${EXPECTED_COUNT} Helm releases to be present (10 min timeout)..."

RETRY=0
MAX_RETRY=40  # 40 * 15s = 10 min
ALL_PRESENT=false
HELM_JSON="[]"
MISSING=""

while [ $RETRY -lt $MAX_RETRY ]; do
  HELM_JSON=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    -o "ProxyCommand=${PROXY_CMD}" -i "${SSH_KEY}" \
    "ubuntu@${CONTROL_IP}" \
    "sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml helm list -A --output json" 2>/dev/null || echo "[]")

  FOUND_COUNT=0
  MISSING=""
  for RELEASE in $EXPECTED_RELEASES; do
    if echo "$HELM_JSON" | grep -q "\"${RELEASE}\""; then
      FOUND_COUNT=$((FOUND_COUNT + 1))
    else
      MISSING="${MISSING} ${RELEASE}"
    fi
  done

  echo "Attempt $((RETRY + 1))/$MAX_RETRY: ${FOUND_COUNT}/${EXPECTED_COUNT} releases present"

  if [ "$FOUND_COUNT" -ge "$EXPECTED_COUNT" ]; then
    echo "All expected Helm releases are present"
    ALL_PRESENT=true
    break
  fi

  if [ -n "$MISSING" ]; then
    echo "  Missing:${MISSING}"
  fi

  RETRY=$((RETRY + 1))
  sleep 15
done

# Build release table for summary
{
  echo "### Helm Release Validation"
  echo ""
  echo "| Release | Chart | Status | Namespace |"
  echo "|---------|-------|--------|-----------|"
} >> "$GITHUB_STEP_SUMMARY"

HAS_NON_DEPLOYED=false
for RELEASE in $EXPECTED_RELEASES; do
  CHART=$(echo "$HELM_JSON" | python3 -c "
import json, sys
releases = json.load(sys.stdin)
match = [r for r in releases if r['name'] == '${RELEASE}']
print(match[0]['chart'] if match else 'NOT FOUND')
" 2>/dev/null || echo "NOT FOUND")

  STATUS=$(echo "$HELM_JSON" | python3 -c "
import json, sys
releases = json.load(sys.stdin)
match = [r for r in releases if r['name'] == '${RELEASE}']
print(match[0]['status'] if match else 'MISSING')
" 2>/dev/null || echo "MISSING")

  NAMESPACE=$(echo "$HELM_JSON" | python3 -c "
import json, sys
releases = json.load(sys.stdin)
match = [r for r in releases if r['name'] == '${RELEASE}']
print(match[0]['namespace'] if match else '-')
" 2>/dev/null || echo "-")

  echo "| ${RELEASE} | ${CHART} | ${STATUS} | ${NAMESPACE} |" >> "$GITHUB_STEP_SUMMARY"

  if [ "$STATUS" != "deployed" ] && [ "$STATUS" != "MISSING" ]; then
    HAS_NON_DEPLOYED=true
  fi
done

echo "" >> "$GITHUB_STEP_SUMMARY"

if [ "$ALL_PRESENT" != "true" ]; then
  echo "::error::Expected Helm releases not found after 10 minutes. Missing:${MISSING}"
  exit 1
fi

if [ "$HAS_NON_DEPLOYED" = "true" ]; then
  echo "::warning::Some Helm releases are not in 'deployed' status"
fi

echo "All ${EXPECTED_COUNT} Helm releases validated successfully"
