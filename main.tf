terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region = var.region
}
variable "region" {
  description = "AWS region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}
resource "aws_instance" "example" {
  ami           = "ami-0e001c9271cf7f3b9"   # Amazon Linux 2 (us-east-1)
  instance_type = var.instance_type

  tags = {
    Name = "devshop-${var.environment}"
  }
}
