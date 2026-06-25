terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.18.0"
    }
  }

  backend "s3" {

    # FILL THIS UP
    # replace with the bucket name you just created in the prereq
    bucket = "waffen-week3-terraform-bucket"

    # if you have multiple state files in the same bucket you may have to replace this
    key = "state/terraform.tfstate"

    # FILL THIS UP
    # replace with the region you are assigned in
    region  = "ap-northeast-2"
    encrypt = true
  }
}
