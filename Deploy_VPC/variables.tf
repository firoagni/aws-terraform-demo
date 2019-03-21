variable "access_key" {
  description = "AWS access key"
}

variable "secret_key" {
  description = "AWS secret key"
}

variable "aws_region" {
  description = "Region for the VPC"
  default = "ap-south-1"
}

variable "vpc_name" {
    description = "Name of the VPC"
    default = "vpc_terraform"
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
  default = "10.0.3.0/24"
}

variable "ami" {
  description = "Amazon Linux AMI 2018.03.0 (HVM), SSD Volume Type"
  default = "ami-0ad42f4f66f6c1cc9"
}

variable "instance_type_application_server" {
  description = "Instance type of the Application Server"
  default = "t2.micro"
}

variable "instance_type_database_server" {
  description = "Instance type of the Database Server"
  default = "t2.micro"
}

variable "ssh_key_name"{
 description = "Name of the SSH key"
 default = "terraformSSHKey"
}