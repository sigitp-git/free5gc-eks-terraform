output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "multus_subnet_ids" {
  description = "All Multus subnet IDs"
  value = {
    n2 = aws_subnet.multus_n2[*].id
    n3 = aws_subnet.multus_n3[*].id
    n4 = aws_subnet.multus_n4[*].id
    n6 = aws_subnet.multus_n6[*].id
  }
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = aws_nat_gateway.nat[*].id
}
