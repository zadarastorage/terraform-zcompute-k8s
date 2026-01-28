output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_eip.bastion.public_ip
}

output "ssh_key_name" {
  description = "AWS key pair name for SSH access to bastion and cluster nodes"
  value       = var.ssh_public_key != "" ? aws_key_pair.ci[0].key_name : ""
}
