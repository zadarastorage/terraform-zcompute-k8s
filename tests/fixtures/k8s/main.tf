locals {
  cluster_name = "test-k8s-${var.run_id}"
}

module "k8s" {
  source = "../../.."

  vpc_id  = var.vpc_id
  subnets = var.private_subnets

  cluster_name    = local.cluster_name
  cluster_version = "1.31.2"
  cluster_token   = var.cluster_token

  tags = {
    "managed-by" = "integration-test"
    "run-id"     = var.run_id
  }

  node_group_defaults = {
    cluster_flavor       = "k3s-ubuntu"
    root_volume_size     = 64
    iam_instance_profile = var.iam_instance_profile
    security_group_rules = {
      egress_ipv4 = {
        description = "Allow all outbound ipv4 traffic"
        protocol    = "all"
        from_port   = 0
        to_port     = 65535
        type        = "egress"
        cidr_blocks = ["0.0.0.0/0"]
      }
    }
  }

  # Minimal cluster for testing - single control plane node
  node_groups = {
    control = {
      role         = "control"
      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }
}

# Look up the load balancer created by the K8s module
# The module creates it with name: ${substr(cluster_name, 0, 27)}-kapi
data "aws_lb" "kube_api" {
  name = "${substr(local.cluster_name, 0, 27)}-kapi"

  depends_on = [module.k8s]
}
