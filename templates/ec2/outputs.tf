output "instance_ids" {
  value = aws_instance.this[*].id
}

output "private_ips" {
  value = aws_instance.this[*].private_ip
}

output "public_ips" {
  value = aws_instance.this[*].public_ip
}

output "ami_id" {
  value = local.ami_id
}

output "subnet_id" {
  value = local.subnet_id
}

output "security_group_id" {
  value = one(aws_security_group.this[*].id)
}
