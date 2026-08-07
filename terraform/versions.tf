terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Terraform Cloud backend — one workspace for the Control Plane infra itself
  # Comment this out for local state during initial bootstrap
  # backend "remote" {
  #   organization = "mitto-sh"
  #   workspaces {
  #     name = "mitto-infra-prod"
  #   }
  # }
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

# us-east-1 is required for ACM certs used with CloudFront
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Platform    = "mitto"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
