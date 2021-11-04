terraform {
  backend "s3" {
    bucket = "terraform-ac2"
    key = "states/terraform.tfstate"
    region = "us-east-1"
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

// Providers
provider "aws" {
  profile = "default"
  # $HOME/.aws/credentials
  region = "us-east-1"
}

// Variables
variable "AMBIENTE" {
  description = "Selección de Ambiente: QA|PROD"
  default = "QA"
  type = string
}
variable "VPC_CIDR" {
  description = "Desarrollo: 10.10 | Producción: 10.11"
  default = "10.10"
  type = string
}
variable "AWS_REGION" {
  description = "AWS Hardcoded region"
  default = "us-east-1"
  type = string
}

module "ssh_key_gen" {
  source = "./modules/ssh_key"
  namespace = var.AMBIENTE
}

// Setup
resource "aws_vpc" "main" {
  cidr_block = "${var.VPC_CIDR}.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "vpc-${var.AMBIENTE}"
    "Automated" = "Yes"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main"
    Automated = "Yes"
  }
}

// Cluster
resource "aws_ecs_cluster" "main_cluster" {
  name = lower("ort-${var.AMBIENTE}")
  setting {
    name = "containerInsights"
    value = "disabled"
  }
  tags = {
    Name = "ort-${var.AMBIENTE}"
  }
}

// Route Tables
resource "aws_route_table" "vpc_public_route_table" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "grupo1_route_table"
    "Automated" = "Yes"
  }
}
resource "aws_route" "vpc_public_route_1" {
  route_table_id = aws_route_table.vpc_public_route_table.id
  gateway_id = aws_internet_gateway.gw.id
  destination_cidr_block = "0.0.0.0/16"
  tags = {
    "Name" = "grupo1_route_1"
    "Automated" = "Yes"
  }
}

// subnets
resource "aws_subnet" "vpc_subnet1" {
  cidr_block = "${var.VPC_CIDR}.1.0/24"
  vpc_id = aws_vpc.main.id
  availability_zone = var.AWS_REGION
  map_public_ip_on_launch = true
  tags = {
    Name = "vpc_subnet1"
    Automated = "Yes"
  }
}
resource "aws_subnet" "vpc_subnet2" {
  cidr_block = "${var.VPC_CIDR}.2.0/24"
  vpc_id = aws_vpc.main.id
  availability_zone = var.AWS_REGION
  map_public_ip_on_launch = true
  tags = {
    Name = "vpc_subnet2"
    Automated = "Yes"
  }
}

// SG Webtransfer
resource "aws_security_group" "sg_web" {
  name = "sg-web"
  description = "Security group para permitir tráfico 80 y 443"
  ingress {
    from_port = 80
    protocol = "TCP"
    to_port = 80
    cidr_blocks = [
      "0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    protocol = "TCP"
    to_port = 433
    cidr_blocks = [
      "0.0.0.0/0"]
  }
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}

// SG SSH
resource "aws_security_group" "sg_ssh" {
  name = "sg-ssh"
  description = "Security group para permitir tráfico SSH"
  ingress {
    from_port = 22
    protocol = "TCP"
    to_port = 22
    cidr_blocks = [
      "0.0.0.0/0"]
  }
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}



locals {
  private_key_name = module.ssh_key_gen.key_name
}