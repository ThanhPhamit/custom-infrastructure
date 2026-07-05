# Remote S3 state. The account-specific values (bucket name embeds the AWS
# account ID, region, profile) live in backend-osaka-prod.hcl, which is
# gitignored so the account ID is never committed. Initialize with:
#   terraform init -backend-config=backend-osaka-prod.hcl
terraform {
  backend "s3" {
    key          = "osaka-prod/terraform.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
