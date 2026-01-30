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

variable "cluster_helm_yaml" {
  description = <<-EOT
    Inline YAML configuration for Helm charts. Charts are configured using a
    chart-centric structure with chart names at the top level.

    YAML Structure:
      <chart-name>:
        enabled: true|false       # Optional, defaults to true
        namespace: <namespace>    # Required
        repository: <url>         # Repository URL
        chart: <chart-name>       # Chart name in repository
        version: "<version>"      # Chart version (quote to avoid YAML number parsing)
        values:                   # Helm values passed to chart
          <key>: <value>

    Example:
      grafana:
        enabled: true
        namespace: monitoring
        repository: https://grafana.github.io/helm-charts
        chart: grafana
        version: "7.0.0"
        values:
          persistence:
            enabled: true

    Multi-Document Support:
      Multiple charts can be defined in separate YAML documents using ---
      separators. This allows modular organization of chart configurations.

      ---
      grafana:
        namespace: monitoring
        ...
      ---
      prometheus:
        namespace: monitoring
        ...

    Variable Injection:
      Use $${cluster_name}, $${endpoint}, $${pod_cidr}, $${service_cidr} to inject
      module variables into your YAML configuration.

      Example:
        cluster-autoscaler:
          values:
            autoDiscovery:
              clusterName: $${cluster_name}

    Escape Mechanism:
      To produce a literal $${} in output (e.g., for Helm templates that use
      similar syntax), use $$${}{} which renders as $${}.

    Merge Behavior:
      When the same chart is defined in both cluster_helm_yaml and
      cluster_helm_values_dir, the file-based configuration takes precedence.
  EOT
  type        = string
  default     = null
}

variable "cluster_helm_values_dir" {
  description = <<-EOT
    Directory containing per-chart YAML configuration files. Each file configures
    a single Helm chart, with the filename (without extension) becoming the
    release name.

    Directory Structure:
      helm-values/
        grafana.yaml        # Configures 'grafana' release
        prometheus.yaml     # Configures 'prometheus' release
        custom-app.yml      # Configures 'custom-app' release

    File Format:
      Each file should contain the chart configuration (NOT wrapped in chart name):

      # grafana.yaml
      enabled: true
      namespace: monitoring
      repository: https://grafana.github.io/helm-charts
      chart: grafana
      version: "7.0.0"
      values:
        persistence:
          enabled: true

    Supported Extensions:
      Both .yaml and .yml extensions are recognized.

    Directory Requirements:
      - Directory must exist when this variable is set
      - Only top-level files are processed (no subdirectory recursion)
      - Empty files are treated as empty configuration (no error)

    Merge Behavior:
      File-based configurations take precedence over cluster_helm_yaml when
      the same chart is defined in both.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.cluster_helm_values_dir == null || can(regex("^[^*?\\[\\]]+$", var.cluster_helm_values_dir))
    error_message = "cluster_helm_values_dir must be a plain directory path, not a glob pattern (cannot contain *, ?, [, or ])"
  }
}
