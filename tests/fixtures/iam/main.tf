locals {
  version_suffix = "v${replace(var.cluster_version, ".", "")}"
  name_prefix    = "test-k8s-${local.version_suffix}-${var.run_id}"
}

module "iam_instance_profile" {
  source = "github.com/zadarastorage/terraform-zcompute-iam-instance-profile?ref=v1.0.0"

  name                  = local.name_prefix
  instance_profile_path = "/"

  use_existing_role   = false
  use_existing_policy = false

  role_name = "${local.name_prefix}-role"
  role_path = "/"

  policy_name = "${local.name_prefix}-policy"
  policy_path = "/"
  policy_contents = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:*",
          "elasticloadbalancing:*",
          "ec2:*",
        ]
        Resource = ["*"]
      },
    ]
  }
}
