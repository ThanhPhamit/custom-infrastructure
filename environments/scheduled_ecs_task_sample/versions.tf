terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.0.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.43.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.7.0"
    }
  }

  required_version = ">= 1.4.6"
}
