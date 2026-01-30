output "garage_private_ip" {
  description = "Private IP of GarageHQ instance"
  value       = aws_instance.garage.private_ip
}

output "garage_endpoint" {
  description = "S3 API endpoint (IP:3900)"
  value       = "${aws_instance.garage.private_ip}:3900"
}

output "garage_instance_id" {
  description = "Instance ID for SSH credential extraction"
  value       = aws_instance.garage.id
}

output "garage_bucket" {
  description = "Ephemeral bucket name created for this run"
  value       = "etcd-backup-${var.run_id}"
}
