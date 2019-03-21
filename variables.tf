variable "vpc_name" {
    description = "Name of the VPC"
    default = "vpc_terraform"
}


variable "aws_region" {
  description = "Region for the VPC"
  default = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for the public subnet"
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR for the private subnet"
  default = "10.0.2.0/24"
}

variable "ami" {
  description = "Amazon Linux AMI"
  default = "ami-4fffc834"
}
variable "public_key_path"{
 description = "Enter the path to the SSH Public Key to add to AWS."
 default = "C:\\Users\\nqx6zo\\Downloads\\office.pem"
}