# K3s Module Examples

This directory contains example configurations demonstrating various K3s cluster deployment patterns on Zadara zCompute.

## Quick Start

1. Choose an example that matches your use case (see matrix below)
2. Copy the example directory to your working location
3. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in your values
4. Run `terraform init && terraform plan && terraform apply`

## Examples

| Example | Description | Control Nodes | Worker Nodes | Features |
|---------|-------------|---------------|--------------|----------|
| [minimal](./minimal/) | Bare essentials | 1 | 0 | Single node, minimal config |
| [minimal-ubuntu](./minimal-ubuntu/) | Ubuntu flavor explicit | 1 | 0 | Ubuntu 22.04 LTS |
| [minimal-debian](./minimal-debian/) | Debian flavor explicit | 1 | 0 | Debian 12 |
| [minimal-mixed](./minimal-mixed/) | Mixed OS flavors | 1 | 2 | Ubuntu control, mixed workers |
| [complete](./complete/) | Full-featured | 3 | 3 | All major options |
| [ha](./ha/) | High availability | 3 | 2 | HA control plane, etcd backup |

## Common Prerequisites

All examples require:

- Terraform >= 1.0
- Zadara zCompute account with API credentials
- Existing VPC with private subnets
- IAM instance profile for K3s nodes
- SSH key pair (for node access)

## Provider Configuration

All examples share a common `versions.tf` in this directory that configures the AWS provider for zCompute. Each example inherits this configuration.

## Validation

To validate an example without credentials:

```bash
cd examples/minimal
terraform init
terraform validate
```

To plan with credentials:

```bash
terraform plan
```

## Related Documentation

- [Main Module README](../README.md) - Full module documentation
- [Architecture](../docs/ARCHITECTURE.md) - Module design and data flow
