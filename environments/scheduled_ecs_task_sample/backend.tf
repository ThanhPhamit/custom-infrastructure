terraform {
  backend "s3" {
    bucket       = "remark-ai-tool-tfstates"
    region       = "ap-northeast-3"
    key          = "osaka-prod/terraform.tfstate"
    profile      = "welfan-lg-mfa"
    use_lockfile = true
  }
}
