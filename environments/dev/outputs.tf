output "vpc_id" {
  description = "VPC ID"
  value       = module.free5gc_eks.vpc_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.free5gc_eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.free5gc_eks.cluster_endpoint
}

output "region" {
  description = "AWS region"
  value       = module.free5gc_eks.region
}
