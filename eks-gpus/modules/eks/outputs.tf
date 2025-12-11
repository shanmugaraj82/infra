output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_oidc_issuer" {
  value = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "gpu_node_group_name" {
  value = aws_eks_node_group.gpu.node_group_name
}

output "ml_irsa_role_arn" {
  value = aws_iam_role.ml_irsa_role.arn
}
