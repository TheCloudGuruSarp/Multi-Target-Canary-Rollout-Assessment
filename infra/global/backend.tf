terraform {
  backend "s3" {
    bucket         = "YARD-REAAS-TFSTATE-BUCKET-ISMINIZ"
    key            = "global/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "YARD-REAAS-TFSTATE-LOCK-TABLOSU"
    encrypt        = true
  }
}
