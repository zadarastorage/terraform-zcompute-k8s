module "iam_instance_profile" {
  source = "github.com/zadarastorage/terraform-zcompute-iam-instance-profile?ref=v1.0.0"

  name                  = "test-k8s-${var.run_id}"
  instance_profile_path = "/"

  use_existing_role   = false
  use_existing_policy = false

  role_name = "test-k8s-role-${var.run_id}"
  role_path = "/"

  policy_name = "test-k8s-policy-${var.run_id}"
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
