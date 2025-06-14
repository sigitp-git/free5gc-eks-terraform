provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

module "vpc" {
  source = "./modules/vpc"

  region               = var.region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  cluster_name         = var.cluster_name
  environment          = var.environment
}

module "eks" {
  source = "./modules/eks"

  cluster_name         = var.cluster_name
  cluster_version      = var.cluster_version
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  multus_subnet_ids    = module.vpc.multus_subnet_ids
  environment          = var.environment
  region               = var.region

  depends_on = [module.vpc]
}

module "kubernetes" {
  source = "./modules/kubernetes"

  cluster_name         = var.cluster_name
  region               = var.region

  depends_on = [module.eks]
}
