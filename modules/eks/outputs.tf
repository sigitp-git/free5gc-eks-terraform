output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.eks_cluster_sg.id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = aws_security_group.eks_node_sg.id
}

output "multus_security_group_id" {
  description = "Security group ID for Multus ENIs"
  value       = aws_security_group.multus_sg.id
}

output "node_groups" {
  description = "EKS node groups"
  value = {
    control_plane = aws_eks_node_group.free5gc_control_plane.id
    ueransim      = aws_eks_node_group.ueransim.id
    upf1          = aws_eks_node_group.upf1.id
    upf2          = aws_eks_node_group.upf2.id
  }
}
