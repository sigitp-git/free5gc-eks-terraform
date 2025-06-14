resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.cluster_name}-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.cluster_name}-igw"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                           = "${var.cluster_name}-public-${var.availability_zones[count.index]}"
    Environment                                    = var.environment
    "kubernetes.io/cluster/${var.cluster_name}"    = "shared"
    "kubernetes.io/role/elb"                       = "1"
  }
}

# Private Kubernetes Subnets
resource "aws_subnet" "private" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 2)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                                           = "${var.cluster_name}-private-${var.availability_zones[count.index]}"
    Environment                                    = var.environment
    "kubernetes.io/cluster/${var.cluster_name}"    = "shared"
    "kubernetes.io/role/internal-elb"              = "1"
  }
}

# Multus N2 Subnets
resource "aws_subnet" "multus_n2" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 4)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.cluster_name}-multus-n2-${var.availability_zones[count.index]}"
    Environment = var.environment
    Network     = "N2"
  }
}

# Multus N3 Subnets
resource "aws_subnet" "multus_n3" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 6)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.cluster_name}-multus-n3-${var.availability_zones[count.index]}"
    Environment = var.environment
    Network     = "N3"
  }
}

# Multus N4 Subnets
resource "aws_subnet" "multus_n4" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 8)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.cluster_name}-multus-n4-${var.availability_zones[count.index]}"
    Environment = var.environment
    Network     = "N4"
  }
}

# Multus N6 Subnets
resource "aws_subnet" "multus_n6" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.cluster_name}-multus-n6-${var.availability_zones[count.index]}"
    Environment = var.environment
    Network     = "N6"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name        = "${var.cluster_name}-nat-eip-${var.availability_zones[count.index]}"
    Environment = var.environment
  }
}

# NAT Gateways
resource "aws_nat_gateway" "nat" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.cluster_name}-nat-${var.availability_zones[count.index]}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.igw]
}

# Route Tables for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.cluster_name}-public-rt"
    Environment = var.environment
  }
}

# Route Tables for Private Subnets
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name        = "${var.cluster_name}-private-rt-${var.availability_zones[count.index]}"
    Environment = var.environment
  }
}

# Route Tables for Multus Subnets
resource "aws_route_table" "multus" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name        = "${var.cluster_name}-multus-rt-${var.availability_zones[count.index]}"
    Environment = var.environment
  }
}

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Route Table Associations for Multus N2 Subnets
resource "aws_route_table_association" "multus_n2" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.multus_n2[count.index].id
  route_table_id = aws_route_table.multus[count.index].id
}

# Route Table Associations for Multus N3 Subnets
resource "aws_route_table_association" "multus_n3" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.multus_n3[count.index].id
  route_table_id = aws_route_table.multus[count.index].id
}

# Route Table Associations for Multus N4 Subnets
resource "aws_route_table_association" "multus_n4" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.multus_n4[count.index].id
  route_table_id = aws_route_table.multus[count.index].id
}

# Route Table Associations for Multus N6 Subnets
resource "aws_route_table_association" "multus_n6" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.multus_n6[count.index].id
  route_table_id = aws_route_table.multus[count.index].id
}
