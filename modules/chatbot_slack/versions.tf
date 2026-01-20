terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.86.1"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.43.0"
    }
  }
  required_version = ">= 1.4.6"
}
