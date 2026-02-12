# Helm Chart Configuration (YAML)

This document describes how to configure Helm charts deployed by the terraform-zcompute-k8s module using YAML format.

> **Note:** As of v1.1, Helm configuration uses YAML format exclusively. The previous HCL-based `cluster_helm` variable has been removed. See [Migration from v1.0](#migration-from-v10) for upgrade instructions.

## Overview

The module supports two ways to provide Helm chart configuration:

1. **Inline YAML** (`cluster_helm_yaml`) - Configuration embedded directly in Terraform
2. **Directory-based** (`cluster_helm_values_dir`) - Per-chart YAML files in a directory

Both methods can be used together. Configuration is merged with module defaults using the following precedence (later wins):

1. Module defaults
2. Inline YAML (`cluster_helm_yaml`)
3. Directory files (`cluster_helm_values_dir`)

## YAML Schema

Each chart is configured at the top level by its release name:

```yaml
<release-name>:
  enabled: true|false      # Optional, defaults to true
  namespace: <string>      # Kubernetes namespace
  repository: <url>        # Helm repository URL (alias: repository_url)
  repository_name: <name>  # Repository name for helm repo add
  chart: <chart-name>      # Chart name in repository
  version: <semver>        # Chart version
  order: <number>          # Installation order (lower runs first)
  wait: true|false         # Wait for resources to be ready
  config:                  # Chart values (passed to helm install --set)
    key: value
    nested:
      key: value
```

## Inline YAML Configuration

Use `cluster_helm_yaml` for simple configurations:

```hcl
module "k8s" {
  source = "github.com/zadarastorage/terraform-zcompute-k8s"

  # ... other required variables ...

  cluster_helm_yaml = <<-YAML
    flannel:
      config:
        podCidr: "10.100.0.0/16"

    cluster-autoscaler:
      config:
        awsRegion: "eu-west-1"
    YAML
}
```

### Multi-Document YAML

For better organization, use YAML document separators (`---`):

```hcl
cluster_helm_yaml = <<-YAML
  ---
  # Networking
  flannel:
    config:
      podCidr: "10.100.0.0/16"

  ---
  # Autoscaling
  cluster-autoscaler:
    config:
      awsRegion: "eu-west-1"
  YAML
```

## Directory-Based Configuration

Use `cluster_helm_values_dir` for larger configurations:

```hcl
module "k8s" {
  source = "github.com/zadarastorage/terraform-zcompute-k8s"

  # ... other required variables ...

  cluster_helm_values_dir = "${path.module}/helm-values"
}
```

Directory structure:
```
helm-values/
  flannel.yaml        # Configures 'flannel' release
  autoscaler.yaml     # Configures 'autoscaler' release (filename = release name)
  monitoring.yaml     # Configures 'monitoring' release
```

Each file contains the chart configuration (release name comes from filename):

```yaml
# helm-values/flannel.yaml
config:
  podCidr: "10.100.0.0/16"
```

### File Naming

- The filename (without extension) becomes the release name
- Both `.yaml` and `.yml` extensions are supported
- Only top-level files are processed (no subdirectory recursion)

## Variable Injection

YAML configurations support variable injection for environment-aware deployments. This works for BOTH inline YAML (`cluster_helm_yaml`) AND directory-based YAML files (`cluster_helm_values_dir`).

| Variable | Description |
|----------|-------------|
| `${cluster_name}` | The cluster name from `var.cluster_name` |
| `${endpoint}` | The zCompute endpoint from `var.zcompute_endpoint` |
| `${pod_cidr}` | The pod CIDR from `var.pod_cidr` |
| `${service_cidr}` | The service CIDR from `var.service_cidr` |

### Example (Inline YAML)

```hcl
cluster_helm_yaml = <<-YAML
  monitoring:
    enabled: true
    namespace: monitoring
    config:
      cluster:
        name: "$${cluster_name}"
        endpoint: "$${endpoint}"
  YAML
```

Note: Use `$${...}` in HCL heredocs to produce `${...}` in the YAML (HCL escaping).

### Example (Directory-based YAML file)

```yaml
# helm-values/monitoring.yaml
enabled: true
namespace: monitoring
config:
  cluster:
    name: "${cluster_name}"
    endpoint: "${endpoint}"
```

### Escaping

To produce a literal `${...}` in the output (e.g., for Helm templates that use similar syntax), use `$${...}` in your YAML:

```yaml
# In a file at helm-values/ebs-csi-driver.yaml
config:
  storageClasses:
    - parameters:
        tagSpecification: "Name=$${.PVName}"  # Produces: Name=${.PVName}
```

For inline YAML in HCL, double-escape with `$$$$`:

```hcl
cluster_helm_yaml = <<-YAML
  ebs-csi-driver:
    config:
      storageClasses:
        - parameters:
            tagSpecification: "Name=$$$$${.PVName}"  # Produces: Name=${.PVName}
  YAML
```

## Merge Behavior

Configuration merges at three levels:

1. **Chart level**: Your charts merge with module defaults (union of all chart names)
2. **Property level**: Properties (namespace, version, etc.) merge within each chart
3. **Config level**: Config keys merge (sibling keys preserved, not replaced)

### Example

Module default:
```yaml
aws-ebs-csi-driver:
  version: "2.39.3"
  config:
    controller:
      region: "us-east-1"
    sidecars:
      provisioner:
        additionalArgs: ["--timeout=120s"]
```

Your override:
```yaml
aws-ebs-csi-driver:
  config:
    controller:
      region: "eu-west-1"
```

Result:
```yaml
aws-ebs-csi-driver:
  version: "2.39.3"           # Preserved from default
  config:
    controller:
      region: "eu-west-1"     # Overridden
    sidecars:                 # Preserved from default
      provisioner:
        additionalArgs: ["--timeout=120s"]
```

## Disabling Charts

Set `enabled: false` to disable a default chart:

```yaml
calico:
  enabled: false

flannel:
  enabled: true
  config:
    podCidr: "10.100.0.0/16"
```

Or set the chart to `null` in the YAML to remove it entirely:

```yaml
calico: null
```

## Hybrid Configuration

Combine inline YAML and directory-based configuration. Directory files take precedence:

```hcl
module "k8s" {
  source = "github.com/zadarastorage/terraform-zcompute-k8s"

  # Base configuration inline
  cluster_helm_yaml = <<-YAML
    flannel:
      config:
        podCidr: "10.100.0.0/16"
    YAML

  # Environment-specific overrides from files
  cluster_helm_values_dir = "${path.module}/helm-values/${var.environment}"
}
```

## Migration from v1.0

v1.1 removes the HCL-based `cluster_helm` variable. To migrate:

1. Run the migration script:
   ```bash
   ./scripts/migrate-helm-config.sh terraform.tfvars > helm-values.yaml
   ```

2. Update your Terraform configuration:
   ```hcl
   # Before (v1.0)
   cluster_helm = {
     flannel = {
       config = {
         podCidr = "10.100.0.0/16"
       }
     }
   }

   # After (v1.1) - inline approach
   cluster_helm_yaml = <<-YAML
     flannel:
       config:
         podCidr: "10.100.0.0/16"
     YAML

   # Or (v1.1) - file-based approach
   cluster_helm_values_dir = "${path.module}/helm-values"
   ```

3. Remove `cluster_helm` from your tfvars file

### Migration Script Usage

```bash
# From tfvars file
./scripts/migrate-helm-config.sh terraform.tfvars

# From stdin
terraform show -json | jq '.values.root_module.resources[].values.cluster_helm' | \
  ./scripts/migrate-helm-config.sh

# Save to file for directory-based approach
./scripts/migrate-helm-config.sh terraform.tfvars > helm-values/charts.yaml
```

## Default Charts

The module includes these charts by default:

| Chart | Purpose | Default Enabled |
|-------|---------|-----------------|
| zadara-aws-config | zCompute cloud configuration | Yes |
| traefik-elb | Load balancer for Traefik ingress | Yes |
| aws-cloud-controller-manager | AWS cloud controller | Yes |
| flannel | Pod networking (CNI) | Yes |
| calico | Alternative CNI (Tigera) | No |
| aws-ebs-csi-driver | EBS storage provisioner | Yes |
| cluster-autoscaler | Node autoscaling | Yes |
| aws-load-balancer-controller | ALB/NLB ingress controller | Yes |

See `locals_helm.tf` for full default configurations.

## Troubleshooting

### YAML Syntax Errors

If you get YAML parsing errors:

1. Validate your YAML with an online validator
2. Check for tabs (YAML requires spaces for indentation)
3. Quote strings containing special characters: `"true"`, `"1.0"`, `"*"`

### Variable Injection Not Working

1. Verify you're using `${variable_name}` syntax (not `$variable_name`)
2. In HCL heredocs, remember to escape: `$${cluster_name}` produces `${cluster_name}`
3. Check that the variable name matches exactly (case-sensitive)

### Charts Not Appearing in Output

1. Check that `enabled: true` or omit the `enabled` key (defaults to true)
2. Verify the chart isn't set to `null` in any configuration source
3. Check precedence: files override inline YAML which overrides defaults

### Config Values Being Lost

The module performs deep merge at the config level. If you're losing sibling config keys:

1. This was fixed in v1.1 - ensure you're using the latest version
2. Verify you're not setting `config: null` in higher-precedence sources
