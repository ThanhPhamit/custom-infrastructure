terraform {
  backend "s3" {
    bucket       = "care-hub-tfstate-storage-aet"
    region       = "ap-northeast-1"
    key          = "tokyo-dev/terraform.tfstate"
    profile      = "clinicmanagementaccount-mfa"
    use_lockfile = true
  }
}
