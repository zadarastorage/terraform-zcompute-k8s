#!/usr/bin/env bash
# Find the oldest control plane node, copy its kubeconfig to bastion.
#
# Required env vars:
#   BASTION_IP   - public IP of the bastion host
#   LB_DNS       - load balancer DNS for the K8s API
#   SSH_KEY      - path to SSH private key
#   EC2_ENDPOINT - zCompute EC2 API endpoint URL
#   RUN_ID       - GitHub Actions run ID (tag filter)
#   GITHUB_OUTPUT - (set by Actions)
set -euo pipefail

PROXY_CMD="ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} -W %h:%p ubuntu@${BASTION_IP}"

# Find the oldest running control plane node via zCompute EC2 API.
# The oldest node is the seed (cluster-init) node — most likely to
# have K3s fully bootstrapped and the kubeconfig ready.
echo "Looking for the oldest control plane node..."
CONTROL_IP=""
for i in $(seq 1 40); do
  CONTROL_IP=$(aws ec2 describe-instances --no-verify-ssl \
    --endpoint-url "${EC2_ENDPOINT}" \
    --filters "Name=tag:run-id,Values=${RUN_ID}" \
              "Name=tag:zadara.com/k8s/role,Values=control" \
              "Name=instance-state-name,Values=running" \
    --query 'sort_by(Reservations[].Instances[], &LaunchTime)[0].PrivateIpAddress' \
    --output text 2>/dev/null || true)

  if [ -n "$CONTROL_IP" ] && [ "$CONTROL_IP" != "None" ] && [ "$CONTROL_IP" != "null" ]; then
    echo "Found oldest control plane node at ${CONTROL_IP}"
    break
  fi
  echo "Attempt ${i}/40: no running control node found yet..."
  sleep 15
done

if [ -z "$CONTROL_IP" ] || [ "$CONTROL_IP" = "None" ] || [ "$CONTROL_IP" = "null" ]; then
  echo "::error::No control plane node found within 10 minutes"
  exit 1
fi

echo "control_ip=$CONTROL_IP" >> "$GITHUB_OUTPUT"

# Wait for K3s to generate kubeconfig on the control node
echo "Waiting for K3s kubeconfig on ${CONTROL_IP}..."
for i in $(seq 1 40); do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
         -o "ProxyCommand=${PROXY_CMD}" -i "${SSH_KEY}" \
         "ubuntu@${CONTROL_IP}" \
         "sudo test -f /etc/rancher/k3s/k3s.yaml" 2>/dev/null; then
    echo "K3s kubeconfig found"
    break
  fi
  echo "Attempt ${i}/40: K3s not ready yet..."
  sleep 15
done

# Extract kubeconfig and replace localhost with LB DNS
ssh -o StrictHostKeyChecking=no -o "ProxyCommand=${PROXY_CMD}" -i "${SSH_KEY}" \
  "ubuntu@${CONTROL_IP}" "sudo cat /etc/rancher/k3s/k3s.yaml" | \
  sed "s|server: https://127.0.0.1:6443|server: https://${LB_DNS}:6443|" \
  > /tmp/kubeconfig.yaml

# Copy to bastion
scp -o StrictHostKeyChecking=no -i "${SSH_KEY}" \
  /tmp/kubeconfig.yaml "ubuntu@${BASTION_IP}:~/kubeconfig.yaml"

echo "::notice::Real K3s kubeconfig copied to bastion (via control node ${CONTROL_IP})"
