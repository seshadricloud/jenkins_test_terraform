# Configure the AWS Provider
provider "aws" {
  region  = "us-west-2"
}

# Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

locals {
  team        = "devops_engineer_dept"
  application = "jenkins_pipeline"
  server_name = "jenkins-${var.environment}-${var.variables_sub_az}"

}

# Terraform Data Block - Lookup Ubuntu 20.04
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

# Define the VPC 
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = var.vpc_name
    Environment = "jenkins_prod_environment"
    Terraform   = "true"
    Region      = data.aws_region.current.name
  }
}

# Deploy the public subnets
resource "aws_subnet" "public_subnets" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value]
  map_public_ip_on_launch = true

  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

# Create route tables for public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name      = "jenkins_public_rtb"
    Terraform = "true"
  }
}

# Create route table associations
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
}

# Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "jenkins_igw"
  }
}

# Generate a TLS private key
resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create an AWS key pair using the generated public key
resource "aws_key_pair" "jenkins_key" {
  key_name   = "jenkins-prod"
  public_key = tls_private_key.jenkins_key.public_key_openssh
}

# Save the private key locally for SSH access
resource "local_file" "jenkins_private_key" {
  content  = tls_private_key.jenkins_key.private_key_pem
  filename = "${path.module}/jenkins-prod.pem"

  provisioner "local-exec" {
    command = "powershell.exe -Command \"& {Set-ItemProperty -Path '${path.module}/jenkins-prod.pem' -Name IsReadOnly -Value $true; (Get-Item '${path.module}/jenkins-prod.pem').Attributes = 'ReadOnly'}\""
  }
}


# Terraform Resource Block - To Build EC2 instance in Public Subnet
resource "aws_instance" "jenkins_server" {                                 # BLOCK
  ami                    = data.aws_ami.ubuntu.id                          # Argument with data expression
  instance_type          = "t2.micro"                                      # Argument
  subnet_id              = aws_subnet.public_subnets["public_subnet_1"].id # Argument with value as expression
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins_s3_access_profile.name
  key_name               = aws_key_pair.jenkins_key.key_name
  tags = {
    Name  = local.server_name
    Owner = local.team
    App   = local.application
  }

  user_data = file(var.jenkins_user_data_file)
}

resource "aws_subnet" "variables-subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.variables_sub_cidr
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = var.variables_sub_auto_ip

  tags = {
    Name      = "sub-variables-${var.variables_sub_az}"
    Terraform = "true"
  }
}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins_security_group"
  description = "Security group for Jenkins EC2 instance"
  vpc_id      = aws_vpc.vpc.id

  # SSH access from your IP address
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Jenkins access on port 8080
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Default egress rule to allow all outgoing traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins_sg"
  }
}

resource "random_string" "random" {
  length  = 10
  special = false
  upper   = false # This ensures uppercase letters are included
  lower   = true  # This ensures lowercase letters are included
  numeric = true  # This ensures numbers are included
}

resource "aws_s3_bucket" "jenkins_artifacts" {
  bucket = "jenkins-artifacts-${random_string.random.result}-bucket" # A unique bucket name using the random string

  tags = {
    Name        = "jenkins-artifacts-bucket"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "jenkins_artifacts_access_block" {
  bucket = aws_s3_bucket.jenkins_artifacts.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "jenkins_s3_access" {
  name = "JenkinsS3AccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_s3_full_access" {
  role       = aws_iam_role.jenkins_s3_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "jenkins_s3_access_profile" {
  name = "JenkinsS3AccessProfile"
  role = aws_iam_role.jenkins_s3_access.name
}