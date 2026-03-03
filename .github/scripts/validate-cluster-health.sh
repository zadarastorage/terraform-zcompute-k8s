#!/usr/bin/env bash
# Enhanced cluster health validation with 4 phases:
#   1. Wait for at least 1 node Ready (fast sanity check)
#   2. Wait for all expected nodes Ready (warning if not all join)
#   3. Verify node roles via labels
#   4. Wait for coredns
#
# Required env vars:
#   BASTION_IP       - public IP of the bastion host
#   SSH_KEY          - path to SSH private key
#   CLUSTER_NAME     - cluster identifier for summary
#   LOAD_BALANCER_DNS - LB DNS for summary
#   GITHUB_STEP_SUMMARY - (set by Actions)
set -euo pipefail

SSH_OPTS="-o StrictHostKeyChecking=no -i ${SSH_KEY}"

bastion_kubectl() {
  ssh $SSH_OPTS "ubuntu@${BASTION_IP}" \
    "KUBECONFIG=~/kubeconfig.yaml kubectl $*"
}

EXPECTED_NODES=4  # 3 control + 1 worker

# --- Phase 1: Wait for at least 1 node Ready (fast sanity check) ---
echo "Phase 1: Waiting for at least 1 node to be Ready..."

RETRY=0
MAX_RETRY=60  # 60 * 15s = 15 min
READY_NODES=0

while [ $RETRY -lt $MAX_RETRY ]; do
  NODES=$(bastion_kubectl get nodes --no-headers 2>/dev/null || true)
  READY_NODES=$(echo "$NODES" | grep -c " Ready" || true)
  TOTAL_NODES=$(echo "$NODES" | grep -c "." || true)

  echo "Attempt $((RETRY + 1))/$MAX_RETRY: Nodes $READY_NODES/$TOTAL_NODES Ready"

  if [ "$READY_NODES" -ge 1 ]; then
    echo "At least one node is Ready"
    break
  fi

  RETRY=$((RETRY + 1))
  sleep 15
done

if [ "$READY_NODES" -lt 1 ]; then
  echo "::error::No nodes became Ready within 15 minutes"
  echo "=== Node Status ==="
  bastion_kubectl get nodes -o wide || true
  echo "=== Node Descriptions ==="
  bastion_kubectl describe nodes || true
  echo "=== System Events ==="
  bastion_kubectl get events -n kube-system --sort-by='.lastTimestamp' || true
  exit 1
fi

# --- Phase 2: Wait for all expected nodes Ready ---
echo "Phase 2: Waiting for all ${EXPECTED_NODES} nodes to be Ready (10 min timeout)..."

RETRY=0
MAX_RETRY=40  # 40 * 15s = 10 min
ALL_READY=false

while [ $RETRY -lt $MAX_RETRY ]; do
  NODES=$(bastion_kubectl get nodes --no-headers 2>/dev/null || true)
  READY_NODES=$(echo "$NODES" | grep -c " Ready" || true)
  TOTAL_NODES=$(echo "$NODES" | grep -c "." || true)

  echo "Attempt $((RETRY + 1))/$MAX_RETRY: Nodes $READY_NODES/$TOTAL_NODES Ready (expecting ${EXPECTED_NODES})"

  if [ "$READY_NODES" -ge "$EXPECTED_NODES" ]; then
    echo "All ${EXPECTED_NODES} expected nodes are Ready"
    ALL_READY=true
    break
  fi

  RETRY=$((RETRY + 1))
  sleep 15
done

if [ "$ALL_READY" != "true" ]; then
  echo "::warning::Only $READY_NODES/$EXPECTED_NODES nodes became Ready within 10 minutes"
  bastion_kubectl get nodes -o wide || true
fi

# --- Phase 3: Verify node roles via labels ---
echo "Phase 3: Verifying node roles..."

CONTROL_NODES=$(bastion_kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers 2>/dev/null | grep -c " Ready" || true)
WORKER_NODES=$(bastion_kubectl get nodes --no-headers 2>/dev/null | grep -vc "control-plane" || true)

echo "Control plane nodes Ready: ${CONTROL_NODES}"
echo "Worker nodes: ${WORKER_NODES}"

if [ "$CONTROL_NODES" -lt 1 ]; then
  echo "::error::No control plane nodes found with expected labels"
  bastion_kubectl get nodes --show-labels || true
  exit 1
fi

# --- Phase 4: Wait for coredns ---
echo "Phase 4: Checking for coredns pods..."

if ! bastion_kubectl wait --for=condition=Ready pod -l k8s-app=kube-dns -n kube-system --timeout=300s; then
  echo "::error::coredns pods not Ready within 5 minutes"
  echo "=== kube-system Pods ==="
  bastion_kubectl get pods -n kube-system -o wide || true
  echo "=== coredns Pod Descriptions ==="
  bastion_kubectl describe pods -n kube-system -l k8s-app=kube-dns || true
  exit 1
fi

echo "Cluster is healthy!"

# Write health summary
READY_NODE_COUNT=$(bastion_kubectl get nodes --no-headers | grep -c " Ready" || true)
COREDNS_COUNT=$(bastion_kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | grep -c "Running" || true)

cat >> "$GITHUB_STEP_SUMMARY" << EOF
### Cluster Health Validation

| Check | Status |
|-------|--------|
| Nodes Ready | ${READY_NODE_COUNT}/${EXPECTED_NODES} |
| Control Plane Nodes | ${CONTROL_NODES} |
| Worker Nodes | ${WORKER_NODES} |
| coredns Running | ${COREDNS_COUNT} |

**Cluster:** ${CLUSTER_NAME}
**Load Balancer:** ${LOAD_BALANCER_DNS}
EOF
