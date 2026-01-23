# Zadara zCompute K8s Terraform Module

A Terraform module for deploying K3s Kubernetes clusters on Zadara zCompute infrastructure. This module provides automated cluster provisioning with configurable node groups, auto-scaling support, and optional Helm chart pre-loading.

## Features

- **K3s Cluster Deployment**: Deploy lightweight, production-ready K3s clusters
- **Configurable Node Groups**: Define multiple node groups with custom instance types and scaling policies
- **Auto Scaling Groups**: Automatic scaling based on workload demands
- **Multiple OS Support**: Choose between Ubuntu and Debian-based nodes
- **Helm Chart Pre-loading**: Optionally pre-install Helm charts during cluster bootstrap
- **etcd Backup**: Configure automatic etcd backups to S3-compatible object storage
- **Custom Network Configuration**: Configurable pod and service CIDR ranges
- **Load Balancer Integration**: Automatic load balancer provisioning for cluster access
- **Security Groups**: Managed security groups for cluster communication
- **Resource Tagging**: Comprehensive tagging support for all resources

## Usage

### Basic K3s Cluster

This example creates a basic K3s cluster:

```hcl
module "k8s" {
  source = "zadarastorage/k8s/zcompute"
  # It's recommended to pin to a specific version
  # version = "1.0.0"

  cluster_name    = "my-cluster"
  cluster_version = "v1.28.4+k3s1"
  cluster_token   = "my-secure-token"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.private_subnets

  node_groups = {
    control-plane = {
      role          = "control-plane"
      instance_type = "z4.large"
      min_size      = 1
      max_size      = 3
      desired_size  = 1
    }
    workers = {
      role          = "worker"
      instance_type = "z4.xlarge"
      min_size      = 1
      max_size      = 10
      desired_size  = 3
    }
  }

  tags = {
    Environment = "dev"
    Project     = "example"
  }
}
```

## Provider Configuration

To use this module with Zadara zCompute, you must configure the AWS provider with custom endpoints. See the [VPC module documentation](https://github.com/zadarastorage/terraform-zcompute-vpc#provider-configuration) for complete provider setup instructions.

## Examples

Complete working examples are available in the [examples](./examples) directory:

- **[k8s-simple](./examples/k8s-simple)**: Basic K3s cluster deployment with VPC and bastion host

## Requirements and Dependencies

See the terraform-docs generated sections below for detailed requirements, providers, resources, inputs, and outputs.

<!-- BEGIN_TF_DOCS -->
## Requirements

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.33.0, <= 3.35.0 |

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.33.0, <= 3.35.0 |
| <a name="provider_cloudinit"></a> [cloudinit](#provider\_cloudinit) | n/a |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Resources

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_attachment.control](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment) | resource |
| [aws_autoscaling_group.control](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_group.worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_launch_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_configuration) | resource |
| [aws_lb.kube_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.k8s_api_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.kube_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_security_group.k8s](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.k8s_extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.k8s](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.k8s_extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [terraform_data.aws_launch_configuration](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_ami_ids.debian](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami_ids) | data source |
| [aws_ami_ids.ubuntu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami_ids) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
| [cloudinit_config.k8s](https://registry.terraform.io/providers/hashicorp/cloudinit/latest/docs/data-sources/config) | data source |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_flavor"></a> [cluster\_flavor](#input\_cluster\_flavor) | Default flavor of k8s cluster to deploy | `string` | `"k3s-ubuntu"` | no |
| <a name="input_cluster_helm"></a> [cluster\_helm](#input\_cluster\_helm) | List of helmcharts to preload | `any` | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name to be used to describe the k8s cluster | `string` | n/a | yes |
| <a name="input_cluster_token"></a> [cluster\_token](#input\_cluster\_token) | Configure the node join token | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | The k8s base version to use | `string` | n/a | yes |
| <a name="input_etcd_backup"></a> [etcd\_backup](#input\_etcd\_backup) | Configuration to automatically backup etcd to object storage | `map(string)` | `null` | no |
| <a name="input_node_group_defaults"></a> [node\_group\_defaults](#input\_node\_group\_defaults) | User-configurable defaults for all node groups | `any` | `{}` | no |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | Configuration of scalable hosts with a designed configuration. | `any` | `{}` | no |
| <a name="input_pod_cidr"></a> [pod\_cidr](#input\_pod\_cidr) | Customize the cidr range used for k8s pods | `string` | `"10.42.0.0/16"` | no |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | Customize the cidr range used for k8s service objects | `string` | `"10.43.0.0/16"` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | A list of (preferably private) subnets to place the K8s cluster and workers into. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | zCompute VPC ID | `string` | n/a | yes |
| <a name="input_zcompute_endpoint"></a> [zcompute\_endpoint](#input\_zcompute\_endpoint) | zCompute API Endpoint | `string` | `"https://cloud.zadara.com"` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | ID of the cluster security group |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | n/a |
<!-- END_TF_DOCS -->

## Contributing

Contributions are welcome! Please open an issue or pull request for any bugs, feature requests, or improvements.

## License

Apache 2 Licensed. See LICENSE for full details.
