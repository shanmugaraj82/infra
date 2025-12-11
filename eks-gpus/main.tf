module "vpc" {
  source = "./modules/vpc"

  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones  = var.availability_zones
}

module "eks" {
  source = "./modules/eks"

  aws_region        = var.aws_region
  cluster_name      = var.cluster_name
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  eks_version       = var.eks_version

  gpu_instance_type = var.gpu_instance_type
  gpu_desired_size  = var.gpu_desired_size
  gpu_min_size      = var.gpu_min_size
  gpu_max_size      = var.gpu_max_size
}
