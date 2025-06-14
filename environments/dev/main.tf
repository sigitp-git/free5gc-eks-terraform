provider "aws" {
  region = var.region
}

module "free5gc_eks" {
  source = "../../"

  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  environment        = var.environment
}
