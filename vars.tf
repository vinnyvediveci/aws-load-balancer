// variable "access_key" {}
// variable "secret_key" {}
variable "key_path" {
  default = "/Users/Vinul/Desktop/Sinatra Blue Green/Node Deployment/testing_load_balance/terraform.pem"
}

variable "region" {
  default = "eu-west-2"
}

variable "ami" {
  default = "ami-03ac5a9b225e99b02"
}

variable "instance_type" {
  default = "t2.micro"
}