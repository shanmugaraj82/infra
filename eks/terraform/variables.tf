variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  # EKS supports up to 1.34 as of late 2025 :contentReference[oaicite:0]{index=0}
  default     = "1.34"
}
