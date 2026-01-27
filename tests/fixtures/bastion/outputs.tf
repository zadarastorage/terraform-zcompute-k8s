output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_eip.bastion.public_ip
}

output "ssh_private_key" {
  description = "SSH private key for accessing the bastion host"
  value       = tls_private_key.bastion.private_key_pem
  sensitive   = true
}
