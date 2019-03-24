//Terraform script to create a VPC with public and private subnets in region ap-south-1 across all availibility zones
//
// Terrform Tutorials:
// https://blog.gruntwork.io/an-introduction-to-terraform-f17df9c6d180 
// https://www.bogotobogo.com/DevOps/DevOps-Terraform.php
// https://medium.com/@pavloosadchyi/terraform-patterns-and-tricks-i-use-every-day-117861531173
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

//-------------------EC2 instances----------------------------------

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

# Create a security group for the elastic load balancer accessible via the web
resource "aws_security_group" "elb_security_group" {
  name        = "elb_security_group"
  description = "This Security Group allows the load balancer to be accessible via the web using HTTP/HTTPS"
  
  vpc_id      = "${aws_vpc.vpc.id}"

  // ------------ Inbound Rules -----------------------------
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

  // ------------ Outbound Rules -----------------------------
  egress {
    description = "Allow All traffic to pass through"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  //----------------------------------------------------------
  tags {
    Name = "Security Group for load balancer in ${aws_vpc.vpc.tags.Name}"
  }
}

resource "aws_elb" "public_load_balancer" {
  name = "public-load-balancer" //Only alphanumeric characters and hyphens allowed in "name"
  subnets         = ["${aws_subnet.public_subnet_1.id}","${aws_subnet.public_subnet_2.id}"]
  security_groups = ["${aws_security_group.elb_security_group.id}"]
  
  //Defining instances manually is not required as we are going to use autoscaling group to dynamically provision instances:
  //instances       = ["${aws_instance.application_server_1.id}","${aws_instance.application_server_2.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    target              = "HTTP:80/index.html"
    interval            = 30
  }

}

//--------------------------- Autoscaling group ---------------------------------

# Create a security group for the launch configuration
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

  // ------------ Outbound Rules -----------------------------
  egress {
    description = "Allow All traffic to pass through"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } 
  //---------------------------------------------------------
  
  //What is this? Check the comments in 'application_server_launch_config'
  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name = "Public SG for ${aws_vpc.vpc.tags.Name}"
  }
}

#Create Launch Configuration for our application server
resource "aws_launch_configuration" "application_server_launch_config" {
  name = "application_server_launch_config"
  image_id = "${var.ami}"
  instance_type = "${var.instance_type_application_server}"
  key_name = "${var.ssh_key_name}"
  associate_public_ip_address = true
  user_data = "${file("install.sh")}" //"file" is a function that returns the content of the file that is passed to it
  
/*
  Important note: whenever using a launch configuration with an auto scaling group, you must set
  create_before_destroy = true that tells Terraform to always create a replacement resource 
  before destroying an original 
  (e.g. when replacing an EC2 Instance, always create the new 
    instance before deleting the old one)

*/

  lifecycle {
    create_before_destroy = true
  }
  
  /*
    The catch with the create_before_destroy parameter is that 
    if you set it to true on resource X, you also have to set it to 
    true on every resource that X depends on. 
    Therefore for launch configuration, you need to set create_before_destroy 
    to true on the security group that it depends on
  */
  security_groups = ["${aws_security_group.public_security_group.id}"]
}

#Create AutoScaling Group from launch configuration
resource "aws_autoscaling_group" "application_server_autoscaling_group" {
  
  name = "application_server_autoscaling_group"

  launch_configuration = "${aws_launch_configuration.application_server_launch_config.id}"
  
  //A list of subnet IDs to launch resources in:
  vpc_zone_identifier = [
                          "${aws_subnet.public_subnet_1.id}",
                          "${aws_subnet.public_subnet_2.id}"
                        ]
  
  
  min_size = 2
  max_size = 3
  
  load_balancers = ["${aws_elb.public_load_balancer.name}"] //Associate Auto Scaling Group (ASG) with ELB
  
  health_check_type = "ELB" /*
                              This tells the ASG to use the ELB’s health check to 
                              determine if an instance is healthy or not 
                              and to automatically restart instances if the ELB reports them as unhealthy
                            */
  
  tag {
    key = "Name"
    value = "application_server_autoscaling_group"
    propagate_at_launch = true
  }
}