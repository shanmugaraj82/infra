terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Let Terraform pick a compatible 6.x version for the modules
      # version = ">= 6.23.0, < 7.0.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# These are used by IAM policy for ALB controller
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
