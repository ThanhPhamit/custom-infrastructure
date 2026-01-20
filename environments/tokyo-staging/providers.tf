provider "aws" {
  region                   = var.region
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = var.profile
}

provider "aws" {
  alias                    = "virginia"
  region                   = "us-east-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = var.profile
}
    