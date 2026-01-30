variable "zcompute_endpoint" {
  description = "zCompute API Endpoint"
  type        = string
  default     = "https://cloud.zadara.com"
}

variable "module_version" {
  description = <<-EOT
    Module version tag for downloading bootstrap scripts from GitHub.
    Must match a git tag in the terraform-zcompute-k8s repository.

    Example: "v1.2.0"

    The version is baked into the bootstrap loader at terraform plan time.
    Scripts are downloaded from:
    https://raw.githubusercontent.com/{github_org}/{github_repo}/{version}/scripts/
  EOT
  type        = string

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+", var.module_version))
    error_message = "module_version must be a semantic version starting with 'v' (e.g., v1.2.0)"
  }
}

variable "github_org" {
  description = "GitHub organization for bootstrap script downloads"
  type        = string
  default     = "zadarastorage"
}

variable "github_repo" {
  description = "GitHub repository name for bootstrap script downloads"
  type        = string
  default     = "terraform-zcompute-k8s"
}

variable "vpc_id" {
  description = "zCompute VPC ID"
  type        = string
}

variable "subnets" {
  description = "A list of (preferably private) subnets to place the K8s cluster and workers into."
  type        = list(string)
}

variable "cluster_name" {
  description = "Name to be used to describe the k8s cluster"
  type        = string
}

variable "cluster_version" {
  description = "The k8s base version to use"
  type        = string
}

variable "cluster_token" {
  description = "Configure the node join token"
  type        = string
}

variable "cluster_flavor" {
  description = "Default flavor of k8s cluster to deploy"
  type        = string
  default     = "k3s-ubuntu"
}

variable "cluster_helm" {
  description = <<-EOT
    Helm charts to deploy on control plane nodes. Each key is a chart name
    (matching or extending module defaults), value is chart configuration.

    Merge behavior (3-level merge):
    - Level 1 (Chart): User charts merged with default charts (union of chart names)
    - Level 2 (Property): Chart properties merged (namespace, version, config, etc.)
    - Level 3 (Config): Config block keys merged via Terraform merge()

    Key behaviors:
    - User values win at leaf level when both user and default specify the same key
    - Default values preserved when user only specifies partial overrides
    - Config-level siblings are preserved (e.g., both controller and sidecars exist)
    - Deeper nesting within config uses shallow merge (user replaces entire nested object)

    Note: For deep nested overrides within config, you must provide the complete
    subtree you want. Only the top-level config keys are merged; anything deeper
    is replaced wholesale by user values.

    Disabling charts:
    - Set chart to null to completely remove it from deployment
    - Set enabled = false to disable a default chart (keeps config for reference)

    Example:
      cluster_helm = {
        # Override specific config keys - other config keys preserved
        cluster-autoscaler = {
          config = {
            awsRegion = "eu-west-1"  # Adds/overrides awsRegion, keeps other config keys
          }
        }
        # Disable a default chart
        calico = {
          enabled = false
        }
        # Remove a chart entirely
        metrics-server = null
        # Add custom chart (no defaults to merge with)
        my-chart = {
          repository_url = "https://example.com/charts"
          chart          = "my-chart"
          version        = "1.0.0"
          namespace      = "default"
          config         = {}
        }
      }
  EOT
  type        = any
  default     = {}

  validation {
    # Validate that each chart value is either null (to disable) or an object
    condition = alltrue([
      for chart_name, chart_config in var.cluster_helm :
      chart_config == null || can(keys(chart_config))
    ])
    error_message = <<-EOT
      Invalid cluster_helm configuration: Each chart entry must be either null or an object.

      Found invalid value. Check that each chart name maps to an object like:
        chart_name = {
          config = { ... }
        }

      Not a scalar value like:
        chart_name = "string"  # Invalid
        chart_name = 123       # Invalid
    EOT
  }
}

variable "pod_cidr" {
  description = "Customize the cidr range used for k8s pods"
  type        = string
  default     = "10.42.0.0/16"
}

variable "service_cidr" {
  description = "Customize the cidr range used for k8s service objects"
  type        = string
  default     = "10.43.0.0/16"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "node_group_defaults" {
  description = "User-configurable defaults for all node groups"
  type        = any
  default     = {}
}

variable "node_groups" {
  description = <<-EOT
    Configuration of scalable hosts with a designed configuration.

    Each node group can include a cloudinit_config list to add custom cloud-init
    parts. These are APPENDED to module-generated parts (not merged/replaced).

    Cloud-init concatenation behavior:
    - Module generates base cloud-init parts (k3s install, config, etc.)
    - User-provided cloudinit_config parts are appended to the list
    - Parts are ordered by the 'order' key (lower runs first)
    - Module parts use orders 0, 10, 19, 20, 30 - use values around these to
      interleave your parts

    Example:
      node_groups = {
        worker = {
          role         = "worker"
          min_size     = 2
          max_size     = 10
          desired_size = 3
          cloudinit_config = [
            {
              order        = 5   # Runs after order=0, before order=10
              filename     = "pre-k3s-setup.sh"
              content_type = "text/x-shellscript"
              content      = "#!/bin/bash\necho 'Runs before k3s install'"
            },
            {
              order        = 25  # Runs after k3s install (order=20)
              filename     = "post-k3s-setup.sh"
              content_type = "text/x-shellscript"
              content      = "#!/bin/bash\necho 'Runs after k3s install'"
            }
          ]
        }
      }
  EOT
  type        = any
  default     = {}
}

variable "default_instance_type" {
  description = <<-EOT
    Default EC2 instance type for all node groups. Individual node groups can
    override this in their configuration.

    Available instance type families vary by zCompute site hardware configuration.
    Common families include z4 (e.g. z4.large) and zp4 (e.g. zp4.large). Consult
    your zCompute site documentation or administrator to determine which instance
    types are supported at your target site.
  EOT
  type        = string
}

variable "etcd_backup" {
  description = "Configuration to automatically backup etcd to object storage"
  type        = map(string)
  default     = null
  ## Configuration is essentially key=value where the key matches the k3s flag with --etcd- removed. IE --etcd-s3-bucket=bucket would be configured here as { s3-bucket = "bucket" }
  # { s3 = true, s3-endpoint = "", s3-region = "", s3-access-key = "", s3-secret-key = "", s3-bucket = "", s3-folder = "" } ## https://docs.k3s.io/cli/etcd-snapshot#s3-compatible-object-store-support
  # { s3 = true, s3-config-secret=<secretName> } ## Using a k8s secret is not available for restore operations https://docs.k3s.io/cli/etcd-snapshot#s3-configuration-secret-support
}
