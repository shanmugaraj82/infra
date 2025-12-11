variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "eks_version" {
  type = string
}

variable "gpu_instance_type" {
  type = string
}

variable "gpu_desired_size" {
  type = number
}

variable "gpu_min_size" {
  type = number
}

variable "gpu_max_size" {
  type = number
}
