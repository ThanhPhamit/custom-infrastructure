terraform {
  backend "s3" {
    bucket         = "welfan-namecard-tfstates"
    region         = "ap-northeast-1"
    key            = "tokyo-staging/terraform.tfstate"
    dynamodb_table = "welfan-namecard-tokyo-staging-tfstates-locking"
    profile        = "liongarden-mfa"
  }
}
