terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Floor raised 4.0 -> 6.51.0: the optional origin_mtls_config block (origin mTLS,
      # var.origin_client_certificate_arn) is only in the provider schema from v6.51.0
      # (PR #46421), and a dynamic block must exist in the schema even when unused.
      version = ">= 6.51.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}
