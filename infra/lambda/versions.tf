// Standard Terraform and AWS provider configuration.
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

// Configure the S3 backend for the Lambda stack's state.
terraform {
  backend "s3" {
    bucket         = "sarper-erkol-tfstate-bucket" // Use the same S3 bucket
    key            = "lambda/terraform.tfstate"          // Unique key for the Lambda state
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table" // Use the same DynamoDB table
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}
