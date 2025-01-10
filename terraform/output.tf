# Output values

output "public_ip" {
  value = aws_instance.ollama_instance.public_ip
}

output "public_fqdn" {
  value = aws_instance.ollama_instance.public_dns
}

output "instance_id" {
  value = aws_instance.ollama_instance.id
}

output "efs_dns_name" {
  value = aws_efs_file_system.efs.dns_name
}
