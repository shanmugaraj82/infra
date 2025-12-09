output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB created for the demo app ingress"
  value       = kubernetes_ingress_v1.app_ingress.status[0].load_balancer[0].ingress[0].hostname
}

output "alb_url" {
  description = "HTTP URL for the demo app via ALB"
  value       = "http://${kubernetes_ingress_v1.app_ingress.status[0].load_balancer[0].ingress[0].hostname}"
}
