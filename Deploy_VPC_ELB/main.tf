//Terraform script to create a VPC with public and private subnets in region ap-south-1 across all availibility zones
//
// Terrform Tutorials:
// https://medium.com/@pavloosadchyi/terraform-patterns-and-tricks-i-use-every-day-117861531173
// https://www.bogotobogo.com/DevOps/DevOps-Terraform.php
//
//
//Terraform installation
//$ wget https://releases.hashicorp.com/terraform/0.10.7/terraform_0.10.7_linux_386.zip
//$ unzip terraform_0.10.7_linux_386.zip
//$ mv terraform /usr/local/bin/
//$ export PATH=$PATH:/usr/local/bin/
//
//Check the installation: 
//$ terraform -v
//
//Terraform commands to execute this code:
//
// terraform init .
//
// terraform validate .
// OR
// terraform validate -var "var1=value1" -var "var2=value2" .
// OR
// terraform validate -var-file ".\test.tfvars" .
//
// terraform plan .
//
// terraform apply .
// OR
// terraform apply -var-file ".\test.tfvars" "var1=value1" -var "var2=value2" . 
// OR
// terraform apply -var-file ".\test.tfvars" . 
//
// terraform output
//
// terraform destroy .
// OR
// terraform destroy -var-file "test.tfvars" .


###############################################################
#
#           Providers
#
###############################################################

# Define AWS as our provider
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.aws_region}"
}

###############################################################
#
#           Data Sources
#
###############################################################

# Declare the aws_availability_zones data source as availibility_zones
data "aws_availability_zones" "available" {
  state = "available"
}

###############################################################
#
#           Resources
#
###############################################################

//----------------- VPC ---------------------------------
#Create the VPC
resource "aws_vpc" "vpc" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.vpc_name}"
  }
}
//---------------------------------------------------------

//----------------- Subnets -------------------------------
#Create a public subnet in the first available availability_zone
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${var.public_subnet_1_cidr}"
  // availability_zone = "ap-south-1a"
  availability_zone = "${data.aws_availability_zones.available.names[0]}" //Instead of hardcoding AZ for the subnet
                                                                          // we are using aws_availability_zones data source to
                                                                          // create subnet in the first available availability zones


  tags = {
    // Name = "Public ap-south-1a ${var.public_subnet_1_cidr}"
    Name = "Public ${data.aws_availability_zones.available.names[0]} ${var.public_subnet_1_cidr}"
  }
}

#Create a public subnet in the second available availability_zone
resource "aws_subnet" "public_subnet_2" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${var.public_subnet_2_cidr}"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"

  tags = {
    Name = "Public ${data.aws_availability_zones.available.names[1]} ${var.public_subnet_2_cidr}"
  }
}

#Create a private subnet in the first available availability_zone
resource "aws_subnet" "private_subnet" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${var.private_subnet_cidr}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags = {
    Name = "Private ${data.aws_availability_zones.available.names[0]} ${var.private_subnet_cidr}"
  }
}

//----------------------------------------------------------

//------------------- Internet Gateway ----------------------
# Create the internet gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "Internet Gateway for ${aws_vpc.vpc.tags.Name}"
  }
}
//----------------------------------------------------------

//------------------ Route Table ---------------------------
# Create the route table
resource "aws_route_table" "public_route_table" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }

  tags {
    Name = "Public RT for ${aws_vpc.vpc.tags.Name}"
  }
}

# Associate subnet public_subnet_1 to the public_route_table
resource "aws_route_table_association" "public_subnet_1__public_route_table_association" {
  subnet_id = "${aws_subnet.public_subnet_1.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}

# Associate subnet public_subnet_2 to the public_route_table
resource "aws_route_table_association" "public_subnet_2__public_route_table_association" {
  subnet_id = "${aws_subnet.public_subnet_2.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}
//---------------------------------------------------------------

//--------------------- Security Groups -------------------------
# Create a security group for the elastic load balancer accessible via the web
resource "aws_security_group" "elb_security_group" {
  name        = "elb_security_group"
  description = "This Security Group allows the load balancer to be accessible via the web using HTTP/HTTPS"
  
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from anywhere"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
    /*
    NOTE on Egress rules: 
    By default, AWS creates an ALLOW ALL egress rule when creating a new Security Group inside of a VPC. 
    When creating a new Security Group inside a VPC, Terraform will remove this default rule, 
    and require you specifically re-create it if you desire that rule.
   */ 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a security group for EC2 instances in public subnet
resource "aws_security_group" "public_security_group" {
  name = "public_security_group"
  description = "This Security Group allows HTTP/HTTPS within the VPC and SSH connections from anywhere."

  vpc_id="${aws_vpc.vpc.id}"

  // ------------ Inbound Rules -----------------------------
  ingress {
    description = "Allow HTTP within the VPC"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    description = "Allow HTTPS within the VPC"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    description = "Allow SSH from anywhere"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks =  ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ICMP - IPv4 from anywhere"
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  //---------------------------------------------------------

  // ------------ Outbound Rules -----------------------------
  egress {
    description = "Allow All traffic to pass through"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } 
  //---------------------------------------------------------
  
  tags {
    Name = "Public SG for ${aws_vpc.vpc.tags.Name}"
  }
}

# Create the security group for EC2 instances in private subnet
resource "aws_security_group" "private_security_group"{
  name = "private_security_group"
  description = "This Security Group enable MySQL 3306 port, ping and SSH only from the public subnet(s) of ${aws_vpc.vpc.tags.Name}"

  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    description = "allow MYSQL/Aurora from the public subnet(s) of ${aws_vpc.vpc.tags.Name}" 
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["${aws_subnet.public_subnet_1.cidr_block}","${aws_subnet.public_subnet_2.cidr_block}"]
  }

  ingress {
    description = "allow All ICMP -IPv4 from the public subnet(s) of ${aws_vpc.vpc.tags.Name}"
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["${aws_subnet.public_subnet_1.cidr_block}","${aws_subnet.public_subnet_2.cidr_block}"]
  }

  ingress {
    description = "allow SSH from the public subnet(s) of ${aws_vpc.vpc.tags.Name}"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${aws_subnet.public_subnet_1.cidr_block}","${aws_subnet.public_subnet_2.cidr_block}"]
  }

  tags {
    Name = "Private SG for ${aws_vpc.vpc.tags.Name}"
  }
}

//-------------------EC2 instances----------------------------------

# Create application server inside the first public subnet
resource "aws_instance" "application_server_1" {
   ami  = "${var.ami}"
   instance_type = "${var.instance_type_application_server}"
   key_name = "${var.ssh_key_name}"
   subnet_id = "${aws_subnet.public_subnet_1.id}"
   vpc_security_group_ids = ["${aws_security_group.public_security_group.id}"]
   associate_public_ip_address = true //Important 
   source_dest_check = false
   user_data = "${file("install.sh")}" //"file" is a function that returns the content of the file that is passed to it

  tags {
    Name = "Application Server in  \"${aws_subnet.public_subnet_1.tags.Name}\""
  }
}

# Create application server inside the second public subnet
resource "aws_instance" "application_server_2" {
   ami  = "${var.ami}"
   instance_type = "${var.instance_type_application_server}"
   key_name = "${var.ssh_key_name}"
   subnet_id = "${aws_subnet.public_subnet_2.id}"
   vpc_security_group_ids = ["${aws_security_group.public_security_group.id}"]
   associate_public_ip_address = true //Important 
   source_dest_check = false
   user_data = "${file("install.sh")}" //"file" is a function that returns the content of the file that is passed to it

  tags {
    Name = "Application Server in  \"${aws_subnet.public_subnet_2.tags.Name}\""
  }
}

# Create Database server inside the private subnet
resource "aws_instance" "database_server" {
   ami  = "${var.ami}"
   instance_type = "${var.instance_type_database_server}"
   key_name = "${var.ssh_key_name}"
   subnet_id = "${aws_subnet.private_subnet.id}"
   vpc_security_group_ids = ["${aws_security_group.private_security_group.id}"]
   associate_public_ip_address = false
   source_dest_check = false

  tags {
    Name = "Database Server"
  }
}
//-------------------------------------------------------------------------------

//------------------ Elastic Load Balancer --------------------------------------
resource "aws_elb" "elb" {
  name = "elb"

  subnets         = ["${aws_subnet.public_subnet_1.id}","${aws_subnet.public_subnet_2.id}"]
  security_groups = ["${aws_security_group.elb_security_group.id}"]
  instances       = ["${aws_instance.application_server_1.id}","${aws_instance.application_server_2.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}