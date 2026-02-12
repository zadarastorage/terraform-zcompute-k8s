variable "k8s_name" {
  type        = string
  description = ""
}

variable "k8s_version" {
  type        = string
  description = ""
  default     = "1.31.2"
}

variable "cluster_token" {
  type        = string
  description = "Configure the node join token"
}

variable "default_instance_type" {
  description = <<-EOT
    Default instance type for K8s node groups.

    Available instance type families vary by zCompute site hardware configuration.
    Common families include z4 (e.g. z4.large) and zp4 (e.g. zp4.large). Consult
    your zCompute site documentation or administrator to determine which instance
    types are supported at your target site.
  EOT
  type        = string
}

variable "module_version" {
  description = "Module version tag for downloading bootstrap scripts from GitHub"
  type        = string
}

module "k8s" {
  source = "../.."
  # For standalone use, replace with:
  #   source = "github.com/zadarastorage/terraform-zcompute-k8s?ref=v2.0.0"

  vpc_id  = var.vpc_id
  subnets = var.private_subnets

  cluster_token  = var.cluster_token
  module_version = var.module_version

  tags = var.tags

  cluster_name    = var.k8s_name
  cluster_version = var.k8s_version

  default_instance_type = var.default_instance_type

  node_group_defaults = {
    cluster_flavor       = "k3s-ubuntu"
    root_volume_size     = 64
    iam_instance_profile = module.iam-instance-profile.instance_profile_name
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
    key_name = aws_key_pair.this.key_name
    cloudinit_config = [
      {
        order        = 5
        filename     = "cloud-config-registry.yaml"
        content_type = "text/cloud-config"
        content = join("\n", ["#cloud-config", yamlencode({ write_files = [
          { path = "/etc/rancher/k3s/registries.yaml", owner = "root:root", permissions = "0640", encoding = "b64", content = base64encode(yamlencode({
            configs = {}
            mirrors = {
              "*" = {}
              "docker.io" = {
                endpoint = ["https://mirror.gcr.io"]
              }
            }
          })) },
        ] })])
      },
    ]
  }

  node_groups = {
    control = {
      role         = "control"
      min_size     = 3
      max_size     = 3
      desired_size = 3
    }
    worker = {
      role             = "worker"
      min_size         = 1
      max_size         = 3
      desired_size     = 1
      root_volume_size = 256
    }
  }
}

