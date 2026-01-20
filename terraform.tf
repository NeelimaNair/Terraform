terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Adjust version as needed
    }
  }

  required_version = ">= 1.3.0"
}
/* 
#@TODO: Validate setup against the AWS internal website url
#@TODO: Destroy Terraform
#@TODO: Delete the private certificate in certificate manager and private CA created in AWS private certificate authority
*/