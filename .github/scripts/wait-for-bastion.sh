#!/usr/bin/env bash
# Poll until bastion host SSH is ready.
#
# Required env vars:
#   BASTION_IP - public IP of the bastion host
#   SSH_KEY    - path to SSH private key
set -euo pipefail

echo "Waiting for bastion SSH at ${BASTION_IP} (timeout: 10 minutes)"

RETRY=0
MAX_RETRY=40  # 40 * 15s = 10 min
while [ $RETRY -lt $MAX_RETRY ]; do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
         -i "${SSH_KEY}" "ubuntu@${BASTION_IP}" \
         "test -f /tmp/bastion-ready" 2>/dev/null; then
    echo "Bastion is ready"
    exit 0
  fi
  echo "Attempt $((RETRY + 1))/$MAX_RETRY: bastion not ready yet..."
  RETRY=$((RETRY + 1))
  sleep 15
done

echo "::error::Bastion SSH did not become ready within 10 minutes"
exit 1
