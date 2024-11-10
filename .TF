Below is the complete Terraform code structure with modules and root configuration for provisioning an EC2 instance with an automatically selected existing AMI and subnet ID.

Directory Structure

project-root/
├── main.tf
├── variables.tf
├── outputs.tf
├── userdata.sh
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security_group/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ssm/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf

Root Module Files

main.tf

This file includes data sources to retrieve the latest Amazon Linux AMI and an existing subnet. These are passed into the ec2 module.

# Data source to get the latest Amazon Linux 2 AMI
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Data source to retrieve an existing subnet in a specific VPC
data "aws_subnet" "default_subnet" {
  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]  # Referencing the VPC ID from the VPC module
  }
}

module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = var.vpc_cidr_block
  subnet_cidr_blocks = var.subnet_cidr_blocks
}

module "security_group" {
  source = "./modules/security_group"
  vpc_id = module.vpc.vpc_id
}

module "ssm" {
  source           = "./modules/ssm"
  ssm_ssh_key_name = var.ssm_ssh_key_name
  ssh_public_key   = var.ssh_public_key
}

module "ec2" {
  source            = "./modules/ec2"
  ami               = data.aws_ami.latest_amazon_linux.id
  subnet_id         = data.aws_subnet.default_subnet.id
  security_group_id = module.security_group.security_group_id
  instance_type     = var.instance_type
  user_data_path    = var.user_data_path
}

variables.tf

Defines the variables required for the root module.

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "subnet_cidr_blocks" {
  description = "List of subnet CIDR blocks"
  type        = list(string)
}

variable "ssm_ssh_key_name" {
  description = "Name for the SSM parameter to store SSH key"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for accessing EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "user_data_path" {
  description = "Path to the EC2 user data script"
  type        = string
  default     = "${path.module}/userdata.sh"
}

outputs.tf

Defines outputs for resources created by the root module.

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "subnet_ids" {
  value = module.vpc.subnet_ids
}

output "security_group_id" {
  value = module.security_group.security_group_id
}

output "ssm_ssh_key_name" {
  value = module.ssm.ssm_ssh_key_name
}

output "instance_id" {
  value = module.ec2.instance_id
}

output "public_ip" {
  value = module.ec2.public_ip
}

userdata.sh

This file contains the user data script to be used by the EC2 instance to install Tomcat.

#!/bin/bash
# Update system packages
sudo yum update -y

# Install necessary dependencies for Puppet and Git
sudo yum install -y git

# Install Puppet
sudo rpm -Uvh https://yum.puppetlabs.com/puppet-release-el-7.noarch.rpm
sudo yum install -y puppet

# Retrieve the SSH private key from SSM Parameter Store
aws ssm get-parameter --name "${ssm_ssh_key_name}" --with-decryption --query "Parameter.Value" --output text > /home/ec2-user/.ssh/id_rsa
chmod 600 /home/ec2-user/.ssh/id_rsa

# Clone the Puppet configuration repository from GitHub
sudo -u ec2-user git clone git@github.com:your-github-username/puppet-tomcat-setup.git /home/ec2-user/puppet-config

# Apply Puppet configuration for Tomcat
sudo puppet apply /home/ec2-user/puppet-config/init.pp

VPC Module Files (modules/vpc)

main.tf

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
}

resource "aws_subnet" "main" {
  count      = length(var.subnet_cidr_blocks)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_cidr_blocks[count.index]
}

variables.tf

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "subnet_cidr_blocks" {
  description = "List of subnet CIDR blocks"
  type        = list(string)
}

outputs.tf

output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_ids" {
  value = aws_subnet.main[*].id
}

Security Group Module Files (modules/security_group)

main.tf

resource "aws_security_group" "main" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variables.tf

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

outputs.tf

output "security_group_id" {
  value = aws_security_group.main.id
}

SSM Module Files (modules/ssm)

main.tf

resource "aws_ssm_parameter" "ssh_key" {
  name      = var.ssm_ssh_key_name
  type      = "SecureString"
  value     = var.ssh_public_key
}

variables.tf

variable "ssm_ssh_key_name" {
  description = "Name of the SSM parameter for the SSH public key"
  type        = string
}

variable "ssh_public_key" {
  description = "The SSH public key to be used for EC2 instance"
  type        = string
}

outputs.tf

output "ssm_ssh_key_name" {
  value = aws_ssm_parameter.ssh_key.name
}

EC2 Module Files (modules/ec2)

main.tf

resource "aws_instance" "main" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  security_group_ids     = [var.security_group_id]
  associate_public_ip_address = true

  user_data = file(var.user_data_path)

  tags = {
    Name = "TomcatServer"
  }
}

variables.tf

variable "ami" {
  description = "The AMI ID for the EC2 instance"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID to launch the EC2 instance in"
  type        = string
}

variable "security_group_id" {
  description = "The security group ID to associate with the instance"
  type        = string
}

variable "instance_type" {
  description = "The instance type for the EC2 instance"
  type        = string
  default     = "t2.micro"
}

variable "user_data_path" {
  description = "Path to the user data script"
  type        = string
}

outputs.tf

output "instance_id" {
  value = aws_instance.main.id
}

output "public_ip" {
  value = aws_instance.main.public_ip
}

Summary

This structure provides a modular, reusable setup for an EC2 instance with automatic reference to the latest Amazon Linux AMI and an existing subnet ID, as well as the configuration to set up Tomcat using a Puppet configuration stored in a GitHub repository. The user_data script installs Puppet, retrieves the SSH key from SSM, clones the repository, and applies the Puppet configuration.