// Provider is AWS
provider "aws" {
     region = "eu-west-2" 
     // Region set to UK, could be elsewhere
}

data "aws_caller_identity" "current" {} // Used for identifying the current user