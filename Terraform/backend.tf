terraform {
  backend "s3" {
    bucket         = "terraform-state-stockholm-797336051996-eu-north-1-an"
    key            = "terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
  }
}