terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state. Local state is fine for one intern on one laptop and wrong
  # the moment two people touch the same infrastructure.
  # backend "s3" {
  #   bucket         = "tkxel-daig-tfstate"
  #   key            = "aws/daig.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "tkxel-daig-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "daig"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "devops-interns"
      CostCentre  = "training"
    }
  }
}
