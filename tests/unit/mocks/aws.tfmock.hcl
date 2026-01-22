# Mock AWS data and resources for plan-only Terraform tests
# Enables testing without AWS credentials or real infrastructure
#
# These mocks are loaded by mock_provider blocks in test files:
#   mock_provider "aws" { source = "tests/unit/mocks" }

# Mock VPC data source
# Returns simulated VPC attributes for network configuration tests
mock_data "aws_vpc" {
  defaults = {
    id                       = "vpc-mock12345678"
    cidr_block               = "10.0.0.0/16"
    enable_dns_hostnames     = true
    enable_dns_support       = true
    main_route_table_id      = "rtb-mock12345678"
  }
}

# Mock AMI IDs data source
# Returns fake AMI IDs for Ubuntu/Debian image lookups
mock_data "aws_ami_ids" {
  defaults = {
    ids = ["ami-mock12345678abcdef0"]
  }
}

# Mock subnets data source
# Returns subnet IDs for VPC zone identifier tests
mock_data "aws_subnets" {
  defaults = {
    ids = ["subnet-mock1234a", "subnet-mock1234b", "subnet-mock1234c"]
  }
}

# Mock Load Balancer resource
# Simulates NLB for Kubernetes API endpoint
mock_resource "aws_lb" {
  defaults = {
    arn      = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/mock-kapi/1234567890abcdef"
    dns_name = "mock-kapi-1234567890abcdef.elb.us-east-1.amazonaws.com"
  }
}

# Mock Auto Scaling Group resource
# Simulates ASG for control plane and worker node groups
mock_resource "aws_autoscaling_group" {
  defaults = {
    arn  = "arn:aws:autoscaling:us-east-1:123456789012:autoScalingGroup:12345678-1234-1234-1234-123456789012:autoScalingGroupName/mock-asg"
    name = "mock-cluster-control"
  }
}

# Mock Launch Configuration resource
# Simulates launch config for ASG instances
mock_resource "aws_launch_configuration" {
  defaults = {
    name = "mock-cluster_control_20260122120000"
    id   = "mock-cluster_control_20260122120000"
  }
}

# Mock Security Group resource
# Simulates SG for cluster networking
mock_resource "aws_security_group" {
  defaults = {
    id  = "sg-mock12345678"
    arn = "arn:aws:ec2:us-east-1:123456789012:security-group/sg-mock12345678"
  }
}

# Mock LB Target Group resource
# Simulates target group for API server load balancing
mock_resource "aws_lb_target_group" {
  defaults = {
    arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock-kapi/1234567890abcdef"
  }
}
