terraform {
  required_version = ">= 1.6"

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

  # Terraform Cloud backend — separate workspace from the prod Control Plane
  backend "remote" {
    organization = "mitto-sh"
    workspaces {
      name = "mitto-infra-dev"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Platform    = "mitto"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
