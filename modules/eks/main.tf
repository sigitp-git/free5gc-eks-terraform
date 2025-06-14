locals {
  eks_cluster_role_name = "${var.cluster_name}-cluster-role"
  eks_node_role_name    = "${var.cluster_name}-node-role"
}

# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  name = local.eks_cluster_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = local.eks_cluster_role_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Node Group IAM Role
resource "aws_iam_role" "eks_node_role" {
  name = local.eks_node_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = local.eks_node_role_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "s3_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.eks_node_role.name
}

# Custom IAM policy for EC2/networking operations
resource "aws_iam_policy" "custom_networking_policy" {
  name        = "${var.cluster_name}-custom-networking-policy"
  description = "Custom policy for EC2/networking operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:UnassignIpv6Addresses",
          "ec2:AssignIpv6Addresses",
          "s3:Get*",
          "s3:Put*",
          "s3:List*",
          "ec2:AssignPrivateIpAddresses",
          "ec2:AssignIpv6Addresses",
          "ec2:DescribeInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeNetworkInterfaces",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:ModifyInstanceMetadataOptions",
          "ec2:UnassignIpv6Addresses",
          "ec2:UnassignPrivateIpAddresses",
          "ec2:DescribeVpcs",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:ReplaceRoute",
          "ec2:DescribeNetworkInterfacePermissions",
          "ec2:DescribeAddresses",
          "ec2:CreateLocalGatewayRoute",
          "ec2:ModifyLocalGatewayRoute",
          "ec2:DeleteLocalGatewayRoute",
          "ec2:SearchLocalGatewayRoutes",
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
          "sts:AssumeRole",
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DescribeVolumes",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:ModifyInstanceAttribute"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-custom-networking-policy"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "custom_networking_policy_attachment" {
  policy_arn = aws_iam_policy.custom_networking_policy.arn
  role       = aws_iam_role.eks_node_role.name
}

# EKS Cluster Security Group
resource "aws_security_group" "eks_cluster_sg" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-cluster-sg"
    Environment = var.environment
  }
}

# EKS Node Group Security Group
resource "aws_security_group" "eks_node_sg" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for EKS node groups"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow inter-node communication"
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster_sg.id]
    description     = "Allow control plane communication"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH access"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow ICMP ping"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.cluster_name}-node-sg"
    Environment = var.environment
  }
}

# Multus Security Group
resource "aws_security_group" "multus_sg" {
  name        = "${var.cluster_name}-multus-sg"
  description = "Security group for Multus ENIs"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all inbound traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.cluster_name}-multus-sg"
    Environment = var.environment
  }
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_encryption_key.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
    aws_cloudwatch_log_group.eks_cluster_logs
  ]
}

# KMS key for EKS cluster encryption
resource "aws_kms_key" "eks_encryption_key" {
  description             = "KMS key for EKS cluster encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "${var.cluster_name}-encryption-key"
    Environment = var.environment
  }
}

# CloudWatch Log Group for EKS cluster logs
resource "aws_cloudwatch_log_group" "eks_cluster_logs" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30

  tags = {
    Name        = "${var.cluster_name}-logs"
    Environment = var.environment
  }
}

# EC2 Launch Template for EKS Node Groups
resource "aws_launch_template" "eks_node_template" {
  name_prefix   = "${var.cluster_name}-node-template-"
  image_id      = data.aws_ami.eks_node_ami.id
  instance_type = "m6i.4xlarge"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  network_interfaces {
    security_groups = [aws_security_group.eks_node_sg.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.cluster_name}-node"
      Environment = var.environment
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tpl", {
    cluster_name       = var.cluster_name
    multus_subnet_ids  = var.multus_subnet_ids
    multus_sg_id       = aws_security_group.multus_sg.id
    region             = var.region
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 required for security
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "${var.cluster_name}-node-template"
    Environment = var.environment
  }
}

# EKS Node Groups
resource "aws_eks_node_group" "free5gc_control_plane" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-control-plane"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [var.private_subnet_ids[0]]  # AZ1 only
  
  launch_template {
    id      = aws_launch_template.eks_node_template.id
    version = aws_launch_template.eks_node_template.latest_version
  }

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 3
  }

  labels = {
    "cnf" = "free5gc-az1"
  }

  tags = {
    Name        = "${var.cluster_name}-control-plane"
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
    aws_iam_role_policy_attachment.custom_networking_policy_attachment
  ]
}

resource "aws_eks_node_group" "ueransim" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-ueransim"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [var.private_subnet_ids[0]]  # AZ1 only
  
  launch_template {
    id      = aws_launch_template.eks_node_template.id
    version = aws_launch_template.eks_node_template.latest_version
  }

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }

  labels = {
    "cnf" = "ueransim-az1"
  }

  tags = {
    Name        = "${var.cluster_name}-ueransim"
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
    aws_iam_role_policy_attachment.custom_networking_policy_attachment
  ]
}

resource "aws_eks_node_group" "upf1" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-upf1"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [var.private_subnet_ids[0]]  # AZ1 only
  
  launch_template {
    id      = aws_launch_template.eks_node_template.id
    version = aws_launch_template.eks_node_template.latest_version
  }

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }

  labels = {
    "cnf" = "free5gc-upf1-az1"
  }

  tags = {
    Name        = "${var.cluster_name}-upf1"
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
    aws_iam_role_policy_attachment.custom_networking_policy_attachment
  ]
}

resource "aws_eks_node_group" "upf2" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-upf2"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [var.private_subnet_ids[0]]  # AZ1 only
  
  launch_template {
    id      = aws_launch_template.eks_node_template.id
    version = aws_launch_template.eks_node_template.latest_version
  }

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }

  labels = {
    "cnf" = "free5gc-upf2-az1"
  }

  tags = {
    Name        = "${var.cluster_name}-upf2"
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
    aws_iam_role_policy_attachment.custom_networking_policy_attachment
  ]
}

# EKS Add-ons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  tags = {
    Name        = "${var.cluster_name}-vpc-cni"
    Environment = var.environment
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  tags = {
    Name        = "${var.cluster_name}-kube-proxy"
    Environment = var.environment
  }
}
