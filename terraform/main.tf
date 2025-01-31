# Resource file 

terraform {
  required_providers {
    ansible = {
      version = "~> 1.3.0"
      source  = "ansible/ansible"
    }
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

# This s3 bucket needs to be created already
terraform {
  backend "s3" {
    bucket = "tfstate-bucket-auto-intelligence"
    key    = "terraform.tfstate"
    region = "us-east-2"
  }
}

provider "aws" {
  region = "us-east-2"
}

# Really don't need this key pair
#Generate SSH key pair for remote-exec
resource "tls_private_key" "cloud_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}


# Add key for ssh connection
resource "aws_key_pair" "cloud_key" {
  key_name   = "cloud_key"
  public_key = tls_private_key.cloud_key.public_key_openssh
}

resource "aws_vpc" "ollama_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = "true"
  instance_tenancy     = "default"

  tags = {
    Name      = "ollama-VPC"
    Terraform = "true"
  }
}

resource "aws_internet_gateway" "ollama_igw" {
  vpc_id = aws_vpc.ollama_vpc.id

  tags = {
    Name      = "ollama_IGW"
    Terraform = "true"
  }
}

resource "aws_route_table" "ollama_pub_igw" {
  vpc_id = aws_vpc.ollama_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ollama_igw.id
  }

  tags = {
    Name      = "ollama-RouteTable"
    Terraform = "true"
  }
}

resource "aws_subnet" "ollama_subnet" {
  availability_zone       = "us-east-2a"
  cidr_block              = "10.1.0.0/24"
  map_public_ip_on_launch = "true"
  vpc_id                  = aws_vpc.ollama_vpc.id

  tags = {
    Name      = "ollama-Subnet"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "ollama_rt_subnet_public" {
  subnet_id      = aws_subnet.ollama_subnet.id
  route_table_id = aws_route_table.ollama_pub_igw.id
}

resource "aws_security_group" "ollama_security_group" {
  name        = "ollama-sg"
  description = "Security Group for ollama webserver"
  vpc_id      = aws_vpc.ollama_vpc.id

  tags = {
    Name      = "ollama-Security-Group"
    Terraform = "true"
  }
}

# So I can http to Open WebUI for testing and troubleshooting
resource "aws_security_group_rule" "ollama_ingress_access" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["<source_ip>/32"]
  security_group_id = aws_security_group.ollama_security_group.id
}

# So I can ssh to the ec2 instance
resource "aws_security_group_rule" "ssh_ingress_access" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["<source_ip>/32"]
  security_group_id = aws_security_group.ollama_security_group.id
}

# Secure port to Open WebUI
resource "aws_security_group_rule" "https_ingress_access" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["<source_ip>/32"]
  security_group_id = aws_security_group.ollama_security_group.id
}


resource "aws_security_group_rule" "egress_access" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ollama_security_group.id
}

# Create IAM role for EC2 to access S3
resource "aws_iam_role" "ec2_s3_access" {
  name = "ec2_s3_access_role"

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
}

# Create IAM policy for S3 access
resource "aws_iam_role_policy" "s3_access_policy" {
  name = "s3_access_policy"
  role = aws_iam_role.ec2_s3_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::tfstate-bucket-auto-intelligence/*"  # Replace with your bucket name
        ]
      }
    ]
  })
}

# Create IAM instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_s3_profile"
  role = aws_iam_role.ec2_s3_access.name
}

resource "aws_instance" "ollama_instance" {
  instance_type               = "g4dn.xlarge"
  vpc_security_group_ids      = [aws_security_group.ollama_security_group.id]
  associate_public_ip_address = true
  key_name        = aws_key_pair.cloud_key.key_name
  user_data                   = file("user_data.txt")
  ami                         = "ami-0000d18df18b47ae9"
  availability_zone           = "us-east-2a"
  subnet_id                   = aws_subnet.ollama_subnet.id
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

# Specify the root block device to adjust volume size
  root_block_device {
    volume_size = 100        # Set desired size in GB (e.g., 100 GB)
    volume_type = "gp3"      # Optional: Specify volume type (e.g., "gp3" for general purpose SSD)
    delete_on_termination = true  # Optional: Automatically delete volume on instance termination
  }
  
  tags = {
    Name      = "ollama-controller"
    Terraform = "true"
  }
}




# Add created ec2 instance to ansible inventory
resource "ansible_host" "ollama_instance" {
  name   = aws_instance.ollama_instance.public_dns
  groups = ["gateway"]
  variables = {
    ansible_user                 = "ec2-user",
    ansible_ssh_private_key_file = "~/.ssh/id_rsa",
    ansible_python_interpreter   = "/usr/bin/python3",
  }
}


