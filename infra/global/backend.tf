terraform {
  backend "s3" {
    bucket         = "sarper-erkol-tfstate-bucket"
    key            = "global/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}
