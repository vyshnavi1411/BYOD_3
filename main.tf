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

# ================= VARIABLES =================

variable "region" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "environment" {
  type = string
}

# ================= EC2 RESOURCE =================

resource "aws_instance" "example" {
  ami           = "ami-0e001c9271cf7f3b9"   # Amazon Linux 2 (us-east-1)
  instance_type = var.instance_type
  key_name = "My_Ecommerce"
  tags = {
    Name = "byod-${var.environment}"
  }
}

# ================= OUTPUTS (CRITICAL) =================

output "instance_id" {
  value = aws_instance.example.id
}

output "instance_public_ip" {
  value = aws_instance.example.public_ip
}
