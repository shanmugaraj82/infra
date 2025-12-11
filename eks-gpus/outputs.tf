output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority
}

output "cluster_oidc_issuer" {
  description = "EKS OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer
}

output "gpu_node_group_name" {
  description = "Name of GPU node group"
  value       = module.eks.gpu_node_group_name
}

output "ml_irsa_role_arn" {
  description = "IAM Role ARN for ML workload (IRSA)"
  value       = module.eks.ml_irsa_role_arn
}
