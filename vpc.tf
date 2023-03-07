# VPC
# https://www.terraform.io/docs/providers/aws/r/vpc.html
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "tf_handson"
  }
}

# Subnet
# https://www.terraform.io/docs/providers/aws/r/subnet.html
resource "aws_subnet" "public_1a" {
  # 先程作成したVPCを参照し、そのVPC内にSubnetを立てる
  vpc_id = "${aws_vpc.main.id}"

  # Public Subnets
  availability_zone = "ap-northeast-1a"

  cidr_block        = "10.0.1.0/24"

  tags = {
    Name = "tf_handson-public-1a"
  }
}

# Private Subnets
resource "aws_subnet" "private_1a" {
  vpc_id = "${aws_vpc.main.id}"

  availability_zone = "ap-northeast-1a"
  cidr_block        = "10.0.10.0/24"

  tags = {
    Name = "tf_handson-private-1a"
  }
}

# Internet Gateway
# https://www.terraform.io/docs/providers/aws/r/internet_gateway.html
resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "tf_handson"
  }
}

# Elasti IP
# https://www.terraform.io/docs/providers/aws/r/eip.html
resource "aws_eip" "nat_1a" {
  vpc = true

  tags = {
    Name = "tf_handson-natgw-1a"
  }
}

# NAT Gateway
# https://www.terraform.io/docs/providers/aws/r/nat_gateway.html
resource "aws_nat_gateway" "nat_1a" {
  subnet_id     = "${aws_subnet.public_1a.id}" # NAT Gatewayを配置するSubnetを指定
  allocation_id = "${aws_eip.nat_1a.id}"       # 紐付けるElasti IP

  tags = {
    Name = "tf_handson-1a"
  }
}

# Route Table
# https://www.terraform.io/docs/providers/aws/r/route_table.html
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "tf_handson-public"
  }
}

# Route
# https://www.terraform.io/docs/providers/aws/r/route.html
resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = "${aws_route_table.public.id}"
  gateway_id             = "${aws_internet_gateway.main.id}"
}

# Association
# https://www.terraform.io/docs/providers/aws/r/route_table_association.html
resource "aws_route_table_association" "public_1a" {
  subnet_id      = "${aws_subnet.public_1a.id}"
  route_table_id = "${aws_route_table.public.id}"
}

# Route Table (Private)
# https://www.terraform.io/docs/providers/aws/r/route_table.html
resource "aws_route_table" "private_1a" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "tf_handson-private-1a"
  }
}

# Route (Private)
# https://www.terraform.io/docs/providers/aws/r/route.html
resource "aws_route" "private_1a" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = "${aws_route_table.private_1a.id}"
  nat_gateway_id         = "${aws_nat_gateway.nat_1a.id}"
}

# Association (Private)
# https://www.terraform.io/docs/providers/aws/r/route_table_association.html
resource "aws_route_table_association" "private_1a" {
  subnet_id      = "${aws_subnet.private_1a.id}"
  route_table_id = "${aws_route_table.private_1a.id}"
}


# ---------------------------
# Security Group
# ---------------------------
# 自分のパブリックIP取得
data "http" "ifconfig" {
  url = "http://ipv4.icanhazip.com/"
}

variable "allowed_cidr" {
  default = null
}

locals {
  myip          = chomp(data.http.ifconfig.body)
  allowed_cidr  = (var.allowed_cidr == null) ? "${local.myip}/32" : var.allowed_cidr
}

# Security Group作成
resource "aws_security_group" "handson_ec2_sg" {
  name              = "handson-ec2-sg"
  description       = "For EC2 Linux"
  vpc_id            = aws_vpc.main.id
  tags = {
    Name = "tf_handson-ec2-sg"
  }

  # インバウンドルール
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.allowed_cidr]
  }

  # アウトバウンドルール
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}