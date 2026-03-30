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

# Configure SSH for bastion jump host
# Using ~/.ssh/config avoids key/auth issues with ProxyCommand string expansion
mkdir -p ~/.ssh
cat > ~/.ssh/config <<SSHEOF
Host bastion
  HostName ${BASTION_IP}
  User ubuntu
  IdentityFile ${SSH_KEY}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host 10.*
  User ubuntu
  IdentityFile ${SSH_KEY}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  ProxyJump bastion
SSHEOF
chmod 600 ~/.ssh/config

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

# SSH helper: run a command on the control node via bastion jump host
ssh_control() {
  ssh -o ConnectTimeout=10 "ubuntu@${CONTROL_IP}" "$@"
}

# Verify SSH connectivity before entering the wait loop
echo "=== SSH config ==="
cat ~/.ssh/config
echo "=== Verifying bastion connectivity ==="
ssh -o ConnectTimeout=10 "ubuntu@bastion" "echo 'bastion OK'" 2>&1 || echo "::warning::Cannot SSH to bastion"
echo "=== Verifying control node connectivity via bastion ==="
ssh -v -o ConnectTimeout=10 "ubuntu@${CONTROL_IP}" "echo 'control node OK'" 2>&1 || echo "::warning::Cannot SSH to control node (see verbose output above)"

# Wait for K3s to generate kubeconfig on the control node
echo "Waiting for K3s kubeconfig on ${CONTROL_IP}..."
KUBECONFIG_FOUND=false
for i in $(seq 1 40); do
  if ssh_control "sudo test -f /etc/rancher/k3s/k3s.yaml"; then
    echo "K3s kubeconfig found"
    KUBECONFIG_FOUND=true
    break
  fi
  echo "Attempt ${i}/40: K3s not ready yet..."

  # Collect diagnostics at attempts 10, 20, 30, and 40
  if [ $((i % 10)) -eq 0 ]; then
    echo "--- Diagnostics at attempt ${i} ---"
    echo "=== SSH connectivity test ==="
    ssh_control "echo 'SSH OK'" 2>&1 || echo "(SSH to control node failed)"
    echo "=== Bootstrap loader log ==="
    ssh_control "sudo cat /var/log/bootstrap/boot.log" 2>&1 || echo "(SSH failed)"
    echo "=== Bootstrap failure log ==="
    ssh_control "sudo cat /var/log/bootstrap-failed 2>/dev/null || echo 'no failure log'" 2>&1 || echo "(SSH failed)"
    echo "=== Cloud-init status ==="
    ssh_control "cloud-init status" 2>&1 || echo "(SSH failed)"
    echo "=== K3s service status ==="
    ssh_control "sudo systemctl status k3s --no-pager -l 2>/dev/null || echo 'k3s service not found'" 2>&1 || echo "(SSH failed)"
    echo "=== K3s install log (last 20 lines) ==="
    ssh_control "sudo tail -20 /var/log/bootstrap/common-20-setup-k3s.sh.log 2>/dev/null || echo 'no k3s log'" 2>&1 || echo "(SSH failed)"
    echo "--- End diagnostics ---"
  fi

  sleep 15
done

if [ "$KUBECONFIG_FOUND" != "true" ]; then
  echo "::error::K3s kubeconfig not found after 40 attempts (10 minutes)"
  exit 1
fi

# Extract kubeconfig and replace localhost with LB DNS
ssh_control "sudo cat /etc/rancher/k3s/k3s.yaml" | \
  sed "s|server: https://127.0.0.1:6443|server: https://${LB_DNS}:6443|" \
  > /tmp/kubeconfig.yaml

# Copy to bastion
scp /tmp/kubeconfig.yaml "ubuntu@bastion:~/kubeconfig.yaml"

echo "::notice::Real K3s kubeconfig copied to bastion (via control node ${CONTROL_IP})"
