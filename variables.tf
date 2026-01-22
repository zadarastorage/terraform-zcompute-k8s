variable "zcompute_endpoint" {
  description = <<-EOT
    Zadara zCompute API endpoint URL. This is the base URL for all AWS-compatible API calls.

    Example: "https://symphony.us-west-1.zadara.com"
    Default: "https://cloud.zadara.com"
  EOT
  type        = string
  default     = "https://cloud.zadara.com"
}

variable "vpc_id" {
  description = "ID of the VPC where the K8s cluster will be deployed. This VPC must have DNS hostnames and DNS resolution enabled."
  type        = string
}

variable "subnets" {
  description = <<-EOT
    List of subnet IDs for placing K8s nodes. Requirements:
    - Private subnets are recommended for security
    - Subnets must have outbound internet access (NAT Gateway) for pulling container images
    - For high availability, use subnets across multiple availability zones
  EOT
  type        = list(string)
}

variable "trusted_ami_owners" {
  description = <<-EOT
    List of trusted AMI owner IDs for Ubuntu and Debian images.
    SECURITY WARNING: Empty list means no owner restriction (any AMI owner accepted).
    For Zadara zCompute, use: ["1234a701473b61af498f633abdc8c113"]
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for id in var.trusted_ami_owners : can(regex("^[a-z0-9]{32}$", id)) || can(regex("^[0-9]{12}$", id)) || id == "self"
    ])
    error_message = "Each owner ID must be a 32-character hex string, 12-digit AWS account ID, or 'self'."
  }
}

variable "cluster_name" {
  description = <<-EOT
    Name of the K8s cluster. Used for resource naming and Kubernetes node identification.
    - Must be unique within your AWS account/region
    - Used as prefix for EC2 instances, security groups, and load balancers
    - Applied as kubernetes.io/cluster/<name> tag for cloud provider integration
  EOT
  type        = string
}

variable "cluster_version" {
  description = <<-EOT
    Kubernetes version to deploy (K3s distribution). Specify the minor version (e.g., "1.31.2").
    - K3s versions track upstream Kubernetes releases
    - See https://github.com/k3s-io/k3s/releases for available versions
    - Tested versions: 1.28.x, 1.29.x, 1.30.x, 1.31.x
  EOT
  type        = string
}

variable "cluster_token" {
  description = "Shared secret token for node authentication and cluster join. Must be at least 16 characters. Keep this value secure and do not commit to version control."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cluster_token) >= 16
    error_message = "cluster_token must be at least 16 characters for security."
  }
}

variable "cluster_flavor" {
  description = <<-EOT
    Base OS flavor for K3s cluster nodes. Determines the AMI used for node instances.

    Available flavors:
    - "k3s-ubuntu": Ubuntu 22.04 LTS (recommended, most tested)
    - "k3s-debian": Debian 12 (Bookworm)
  EOT
  type        = string
  default     = "k3s-ubuntu"
}

variable "cluster_helm" {
  description = <<-EOT
    Map of Helm charts to deploy during cluster initialization. Each key is a chart identifier
    and value contains chart configuration.

    Supported charts:
    - aws-cloud-controller-manager: AWS/zCompute cloud provider integration
    - aws-ebs-csi-driver: EBS volume provisioner for persistent storage

    Structure:
    ```hcl
    cluster_helm = {
      aws-cloud-controller-manager = {
        enabled = true
      }
      aws-ebs-csi-driver = {
        enabled = true
        values  = { ... }  # Optional: override default Helm values
      }
    }
    ```
  EOT
  type        = any
  default     = {}
}

variable "pod_cidr" {
  description = <<-EOT
    CIDR range for Kubernetes pod networking. Pods are assigned IPs from this range.
    - Must not overlap with VPC CIDR or service_cidr
    - Default /16 provides ~65,000 pod IPs
    - Adjust size based on expected cluster scale
  EOT
  type        = string
  default     = "10.42.0.0/16"
}

variable "service_cidr" {
  description = <<-EOT
    CIDR range for Kubernetes ClusterIP services. Services are assigned IPs from this range.
    - Must not overlap with VPC CIDR or pod_cidr
    - Default /16 provides ~65,000 service IPs
    - First IP (10.43.0.1) is reserved for kubernetes.default service
  EOT
  type        = string
  default     = "10.43.0.0/16"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "node_group_defaults" {
  description = <<-EOT
    Default settings applied to all node groups. Individual node group settings override these defaults.

    Supported keys:
    - instance_type: EC2 instance type (default: "z4.large")
    - root_volume_size: Root EBS volume size in GB (default: 40)
    - root_volume_type: EBS volume type (default: null, uses AWS default)
    - key_name: SSH key pair name for node access
    - iam_instance_profile: IAM instance profile name (required)
    - tags: Additional tags for node group resources
    - feature_gates: List of Kubernetes feature gates to enable
    - security_group_rules: Map of additional security group rules
    - cloudinit_config: List of additional cloud-init config parts

    Example:
    ```hcl
    node_group_defaults = {
      iam_instance_profile = "k8s-node-profile"
      key_name             = "my-ssh-key"
      instance_type        = "z8.xlarge"
      root_volume_size     = 100
    }
    ```
  EOT
  type        = any
  default     = {}
}

variable "node_groups" {
  description = <<-EOT
    Map of node group configurations. Each entry creates an Auto Scaling Group.

    Required keys:
    - role: Node role, either "control" (control plane) or "worker"

    Optional keys (defaults from node_group_defaults):
    - enabled: Whether to create this node group (default: true)
    - min_size: Minimum ASG size (default: 0)
    - max_size: Maximum ASG size (default: 0)
    - desired_size: Initial/desired ASG size (default: 0)
    - instance_type: EC2 instance type (default: "z4.large")
    - root_volume_size: Root EBS volume size in GB (default: 40)
    - key_name: SSH key pair name for node access
    - iam_instance_profile: IAM instance profile name
    - k8s_labels: Map of Kubernetes node labels
    - k8s_taints: Map of Kubernetes node taints (format: "key" = "value:Effect")
    - security_group_rules: Additional security group rules
    - cloudinit_config: Additional cloud-init config parts

    Example:
    ```hcl
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
        max_size         = 10
        desired_size     = 3
        instance_type    = "z8.2xlarge"
        root_volume_size = 256
        k8s_labels = {
          "workload" = "general"
        }
      }
      gpu = {
        role          = "worker"
        min_size      = 0
        max_size      = 4
        desired_size  = 0
        instance_type = "g4.xlarge"
        k8s_taints = {
          "nvidia.com/gpu" = "true:NoSchedule"
        }
      }
    }
    ```
  EOT
  type        = any
  default     = {}
}

variable "etcd_backup" {
  description = <<-EOT
    Configuration for automatic etcd snapshots to S3-compatible object storage.
    When configured, K3s automatically backs up etcd data on a schedule.

    Configuration keys map to K3s etcd-snapshot flags (without --etcd- prefix):
    - s3: Enable S3 backup (set to "true")
    - s3-endpoint: S3 endpoint URL
    - s3-region: S3 region
    - s3-bucket: S3 bucket name
    - s3-folder: Folder path within bucket
    - s3-access-key: S3 access key
    - s3-secret-key: S3 secret key
    - snapshot-schedule-cron: Backup schedule (default: "0 */12 * * *")
    - snapshot-retention: Number of snapshots to retain (default: 5)

    Example:
    ```hcl
    etcd_backup = {
      s3            = "true"
      s3-endpoint   = "https://s3.example.com"
      s3-region     = "us-east-1"
      s3-bucket     = "etcd-backups"
      s3-folder     = "my-cluster"
      s3-access-key = var.backup_access_key
      s3-secret-key = var.backup_secret_key
    }
    ```

    See: https://docs.k3s.io/cli/etcd-snapshot#s3-compatible-object-store-support
  EOT
  type        = map(string)
  default     = null
  sensitive   = true
}
