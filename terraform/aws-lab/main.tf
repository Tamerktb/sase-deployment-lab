terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── Networking ────────────────────────────────────────────────────────
resource "aws_vpc" "sase" {
  cidr_block           = "10.200.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "sase-aws-lab" }
}

resource "aws_subnet" "sase" {
  vpc_id                  = aws_vpc.sase.id
  cidr_block              = "10.200.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags                    = { Name = "sase-public" }
}

resource "aws_internet_gateway" "sase" {
  vpc_id = aws_vpc.sase.id
  tags   = { Name = "sase-igw" }
}

resource "aws_route_table" "sase" {
  vpc_id = aws_vpc.sase.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sase.id
  }
  tags = { Name = "sase-public-rt" }
}

resource "aws_route_table_association" "sase" {
  subnet_id      = aws_subnet.sase.id
  route_table_id = aws_route_table.sase.id
}

# ── Security Groups ───────────────────────────────────────────────────
resource "aws_security_group" "sase" {
  name        = "sase-lab"
  description = "SASE AWS Lab security group"
  vpc_id      = aws_vpc.sase.id
  tags        = { Name = "sase-lab-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.sase.id
  cidr_ipv4         = var.allowed_ssh_cidrs[0]
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH"
}

resource "aws_vpc_security_group_ingress_rule" "wireguard" {
  security_group_id = aws_security_group.sase.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 51820
  to_port           = 51820
  ip_protocol       = "udp"
  description       = "WireGuard"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.sase.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP"
}

resource "aws_vpc_security_group_ingress_rule" "metrics" {
  security_group_id = aws_security_group.sase.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8000
  to_port           = 8000
  ip_protocol       = "tcp"
  description       = "Posture metrics"
}

resource "aws_vpc_security_group_ingress_rule" "intra" {
  security_group_id            = aws_security_group.sase.id
  referenced_security_group_id = aws_security_group.sase.id
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "-1"
  description                  = "All traffic between SASE instances"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.sase.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound"
}

# ── AMI Lookup ────────────────────────────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-24.04-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ── SSH Key ───────────────────────────────────────────────────────────
data "aws_key_pair" "existing" {
  key_name           = var.ssh_key_name
  include_public_key = true
}

# ── EC2 Instances ─────────────────────────────────────────────────────
locals {
  hub_tunnel_token = var.cloudflare_tunnel_tokens.hub != "" ? var.cloudflare_tunnel_tokens.hub : ""
}

resource "aws_instance" "hub" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  subnet_id              = aws_subnet.sase.id
  vpc_security_group_ids = [aws_security_group.sase.id]
  user_data              = templatefile("${path.module}/user-data/hub.sh.tpl", { cloudflare_token = local.hub_tunnel_token })

  tags = {
    Name     = "sase-hub"
    Role     = "wireguard-hub"
    Site     = "hub"
    SASE     = "true"
    Teardown = "terraform destroy"
  }
}

resource "aws_instance" "site_a" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  subnet_id              = aws_subnet.sase.id
  vpc_security_group_ids = [aws_security_group.sase.id]
  user_data              = templatefile("${path.module}/user-data/site.sh.tpl", { cloudflare_token = var.cloudflare_tunnel_tokens.site_a })

  tags = {
    Name     = "sase-site-a"
    Role     = "wireguard-peer"
    Site     = "site-a"
    SASE     = "true"
    Teardown = "terraform destroy"
  }
}

resource "aws_instance" "site_b" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  subnet_id              = aws_subnet.sase.id
  vpc_security_group_ids = [aws_security_group.sase.id]
  user_data              = templatefile("${path.module}/user-data/site.sh.tpl", { cloudflare_token = var.cloudflare_tunnel_tokens.site_b })

  tags = {
    Name     = "sase-site-b"
    Role     = "wireguard-peer"
    Site     = "site-b"
    SASE     = "true"
    Teardown = "terraform destroy"
  }
}
