# Free5GC on AWS EKS Terraform

This repository contains Terraform code to deploy Free5GC on AWS EKS with Multus networking capabilities.

## Architecture

The infrastructure is designed based on the Free5GC Low-Level Design (LLD) document and includes:

- VPC with multi-AZ design
- EKS Cluster with managed node groups
- Multus networking support
- AWS-managed add-ons
- Custom IAM roles and security configurations

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform v1.0.0 or later
- kubectl installed
- AWS IAM permissions to create and manage EKS clusters

## Directory Structure

```
free5gc-eks-terraform/
├── modules/
│   ├── vpc/                # VPC and networking resources
│   ├── eks/                # EKS cluster and node groups
│   └── kubernetes/         # Kubernetes resources (Multus, SRIOV, etc.)
├── environments/
│   └── dev/                # Development environment configuration
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Input variables
└── outputs.tf              # Output values
```

## Security Features

- EKS cluster with private API endpoint
- Node groups in private subnets
- IAM roles with least privilege
- Security groups with restricted access
- KMS encryption for EKS secrets
- IMDSv2 required on EC2 instances

## Deployment

1. Initialize Terraform:

```bash
terraform init
```

2. Review the deployment plan:

```bash
terraform plan
```

3. Apply the configuration:

```bash
terraform apply
```

4. Configure kubectl to access the cluster:

```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

## Networking

The infrastructure includes the following network components:

- VPC with CIDR 10.100.0.0/16
- Public subnets for NAT gateways
- Private subnets for Kubernetes nodes
- Multus subnets for N2, N3, N4, and N6 interfaces
- NAT gateways for outbound connectivity
- Security groups for cluster, nodes, and Multus interfaces

## Node Groups

The EKS cluster includes the following node groups:

1. Free5GC Control Plane - For core network functions
2. UERANSIM - For simulating UE and RAN
3. UPF1 - User Plane Function 1
4. UPF2 - User Plane Function 2

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

## Notes

- HugePages are configured on the worker nodes for DPDK support
- SR-IOV is enabled for high-performance networking
- GTP kernel module is loaded for 5G user plane functions
