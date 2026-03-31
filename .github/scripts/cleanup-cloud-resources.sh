#!/usr/bin/env bash
# Clean up cloud-controller-managed resources that Terraform doesn't track.
#
# After K8s destroy, the AWS Cloud Controller Manager and Load Balancer
# Controller may have created ELBs, target groups, security groups, and
# EBS volumes that are not in Terraform state. These must be removed
# before VPC destroy, or the VPC will fail to delete due to dependencies.
#
# Required env vars:
#   VPC_ID       - VPC ID to clean resources from
#   EC2_ENDPOINT - zCompute EC2 API endpoint URL
#   ELB_ENDPOINT - zCompute ELB API endpoint URL
set -euo pipefail

AWS_OPTS="--no-verify-ssl --output json"

echo "Cleaning up cloud-controller resources in VPC ${VPC_ID}..."

# ============================================================
# Phase 1: Load Balancers and Target Groups
# ============================================================
echo "--- Cleaning up load balancers ---"
LBS=$(aws elbv2 describe-load-balancers ${AWS_OPTS} \
  --endpoint-url "${ELB_ENDPOINT}" 2>/dev/null \
  | jq -r --arg vpc "${VPC_ID}" \
    '.LoadBalancers[] | select(.VpcId == $vpc) | .LoadBalancerArn' \
  || true)

for LB_ARN in $LBS; do
  LB_NAME=$(aws elbv2 describe-load-balancers ${AWS_OPTS} \
    --endpoint-url "${ELB_ENDPOINT}" \
    --load-balancer-arns "${LB_ARN}" 2>/dev/null \
    | jq -r '.LoadBalancers[0].LoadBalancerName' || echo "unknown")
  echo "Deleting load balancer: ${LB_NAME} (${LB_ARN})"

  # Delete listeners first
  LISTENERS=$(aws elbv2 describe-listeners ${AWS_OPTS} \
    --endpoint-url "${ELB_ENDPOINT}" \
    --load-balancer-arn "${LB_ARN}" 2>/dev/null \
    | jq -r '.Listeners[].ListenerArn' || true)
  for LISTENER_ARN in $LISTENERS; do
    aws elbv2 delete-listener ${AWS_OPTS} \
      --endpoint-url "${ELB_ENDPOINT}" \
      --listener-arn "${LISTENER_ARN}" 2>/dev/null || true
  done

  aws elbv2 delete-load-balancer ${AWS_OPTS} \
    --endpoint-url "${ELB_ENDPOINT}" \
    --load-balancer-arn "${LB_ARN}" 2>/dev/null || {
      echo "::warning::Failed to delete load balancer ${LB_NAME}"
    }
done

echo "--- Cleaning up orphaned target groups ---"
TGS=$(aws elbv2 describe-target-groups ${AWS_OPTS} \
  --endpoint-url "${ELB_ENDPOINT}" 2>/dev/null \
  | jq -r --arg vpc "${VPC_ID}" \
    '.TargetGroups[] | select(.VpcId == $vpc) | .TargetGroupArn' \
  || true)

for TG_ARN in $TGS; do
  TG_NAME=$(aws elbv2 describe-target-groups ${AWS_OPTS} \
    --endpoint-url "${ELB_ENDPOINT}" \
    --target-group-arns "${TG_ARN}" 2>/dev/null \
    | jq -r '.TargetGroups[0].TargetGroupName' || echo "unknown")
  echo "Deleting target group: ${TG_NAME}"
  aws elbv2 delete-target-group ${AWS_OPTS} \
    --endpoint-url "${ELB_ENDPOINT}" \
    --target-group-arn "${TG_ARN}" 2>/dev/null || {
      echo "::warning::Failed to delete target group ${TG_NAME}"
    }
done

# ============================================================
# Phase 2: EBS Volumes (available = detached/orphaned)
# ============================================================
echo "--- Cleaning up orphaned EBS volumes ---"
VOLUMES=$(aws ec2 describe-volumes ${AWS_OPTS} \
  --endpoint-url "${EC2_ENDPOINT}" \
  --filters "Name=status,Values=available" 2>/dev/null \
  | jq -r --arg vpc "${VPC_ID}" '
    # Filter volumes that were created by PVCs in this VPC
    # Available (not attached) volumes with kubernetes tags are orphans
    [.Volumes[]
     | select(any(.Tags[]?; .Key | startswith("kubernetes.io/")))
    ] | .[].VolumeId' \
  || true)

for VOL_ID in $VOLUMES; do
  echo "Deleting orphaned volume: ${VOL_ID}"
  aws ec2 delete-volume ${AWS_OPTS} \
    --endpoint-url "${EC2_ENDPOINT}" \
    --volume-id "${VOL_ID}" 2>/dev/null || {
      echo "::warning::Failed to delete volume ${VOL_ID}"
    }
done

# ============================================================
# Phase 3: Security Groups (non-default, in this VPC)
# ============================================================
echo "--- Cleaning up orphaned security groups ---"
SECURITY_GROUPS=$(aws ec2 describe-security-groups ${AWS_OPTS} \
  --endpoint-url "${EC2_ENDPOINT}" \
  --filters "Name=vpc-id,Values=${VPC_ID}" 2>/dev/null \
  | jq -r '.SecurityGroups[] | select(.GroupName != "default") | .GroupId' \
  || true)

for SG_ID in $SECURITY_GROUPS; do
  SG_NAME=$(aws ec2 describe-security-groups ${AWS_OPTS} \
    --endpoint-url "${EC2_ENDPOINT}" \
    --group-ids "${SG_ID}" 2>/dev/null \
    | jq -r '.SecurityGroups[0].GroupName' || echo "unknown")

  # Remove all ingress/egress rules first (clears cross-SG references)
  echo "Revoking rules on security group: ${SG_NAME} (${SG_ID})"
  INGRESS=$(aws ec2 describe-security-groups ${AWS_OPTS} \
    --endpoint-url "${EC2_ENDPOINT}" \
    --group-ids "${SG_ID}" 2>/dev/null \
    | jq -c '.SecurityGroups[0].IpPermissions' || echo '[]')
  if [ "$INGRESS" != "[]" ] && [ -n "$INGRESS" ]; then
    aws ec2 revoke-security-group-ingress ${AWS_OPTS} \
      --endpoint-url "${EC2_ENDPOINT}" \
      --group-id "${SG_ID}" \
      --ip-permissions "${INGRESS}" 2>/dev/null || true
  fi

  EGRESS=$(aws ec2 describe-security-groups ${AWS_OPTS} \
    --endpoint-url "${EC2_ENDPOINT}" \
    --group-ids "${SG_ID}" 2>/dev/null \
    | jq -c '.SecurityGroups[0].IpPermissionsEgress' || echo '[]')
  if [ "$EGRESS" != "[]" ] && [ -n "$EGRESS" ]; then
    aws ec2 revoke-security-group-egress ${AWS_OPTS} \
      --endpoint-url "${EC2_ENDPOINT}" \
      --group-id "${SG_ID}" \
      --ip-permissions "${EGRESS}" 2>/dev/null || true
  fi

  echo "Deleting security group: ${SG_NAME} (${SG_ID})"
  aws ec2 delete-security-group ${AWS_OPTS} \
    --endpoint-url "${EC2_ENDPOINT}" \
    --group-id "${SG_ID}" 2>/dev/null || {
      echo "::warning::Failed to delete security group ${SG_NAME} (${SG_ID}) - may still be in use"
    }
done

echo "Cloud-controller resource cleanup complete"
