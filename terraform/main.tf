terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "ddns"
      ManagedBy   = "terraform"
      Environment = "prod"
    }
  }
}

data "aws_route53_zone" "zone" {
  name         = var.zone_name
  private_zone = false
}

locals {
  record_fqdn = trimsuffix(var.record_name, ".")
  zone_fqdn   = trimsuffix(var.zone_name, ".")
}
