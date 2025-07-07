# --------------------------------------------------------
# 0. Specify Terraform version & required providers
# --------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  required_version = "~> 1.12"
}

# --------------------------------------------------------
# Set AWS region for all resources
# --------------------------------------------------------
provider "aws" {
  region = "ap-south-1" # Mumbai region
}

# --------------------------------------------------------
# 1. Ensure a default VPC exists (AWS will create if none)
# --------------------------------------------------------
resource "aws_default_vpc" "default" {}

# --------------------------------------------------------
# 2. Generate an SSH key pair with Terraform
# --------------------------------------------------------
resource "tls_private_key" "artmograph_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "artmograph_key" {
  key_name   = "artmograph-key"
  public_key = tls_private_key.artmograph_key.public_key_openssh
}

resource "local_file" "artmograph_private_key" {
  content         = tls_private_key.artmograph_key.private_key_pem
  filename        = "${path.module}/artmograph.pem"
  file_permission = "0600"
}

# --------------------------------------------------------
# 3. Create a security group in the default VPC
# --------------------------------------------------------
resource "aws_security_group" "artmograph_security_group" {
  name        = "artmograph-security-group"
  description = "Allow SSH, HTTP, HTTPS, and MQTT access"
  vpc_id      = aws_default_vpc.default.id

  # Allow SSH on port 22 (so you can connect via SSH client)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP on port 80 (for serving web pages)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS on port 443 (for secure web traffic)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow MQTT on port 1883 (for IoT / message brokers)
  ingress {
    from_port   = 1883
    to_port     = 1883
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic (so your instance can reach the internet)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --------------------------------------------------------
# 4. Launch the EC2 instance
# --------------------------------------------------------
resource "aws_instance" "artmograph_ec2" {
  ami                    = "ami-08e0ca9924195beba"
  instance_type          = "t2.small"
  key_name               = aws_key_pair.artmograph_key.key_name
  vpc_security_group_ids = [aws_security_group.artmograph_security_group.id]

  root_block_device {
    volume_size = 100
  }

  tags = {
    Name = "Artmograph-Server"
  }
}

# --------------------------------------------------------
# 5. Allocate a static Elastic IP and attach it to the instance
# --------------------------------------------------------
resource "aws_eip" "artmograph_static_ip" {
  instance = aws_instance.artmograph_ec2.id
}

# --------------------------------------------------------
# 6. Output the static public IP so you can SSH in
# --------------------------------------------------------
output "instance_static_ip" {
  description = "Static public IP of your Artmograph EC2 server"
  value       = aws_eip.artmograph_static_ip.public_ip
}
