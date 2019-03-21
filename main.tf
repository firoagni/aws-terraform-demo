//Terraform script to create a VPC with public and private subnets in region ap-south-1 across all availibility zones
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
// terraform init .
// terraform validate .
// terraform plan .
// terraform apply .
// terraform output
// terraform destroy .

# Define AWS as our provider
provider "aws" {
  region     = "ap-south-1"
}
//----------------- VPC ---------------------------------
#Create the VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "vpc_terraform"
  }
}
//---------------------------------------------------------

//----------------- Subnets -------------------------------
#Create the public subnet on availability_zone ap-south-1a
resource "aws_subnet" "public_subnet_ap_south_1a" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "Public ap-south-1a 10.0.3.0/24"
  }
}

#Create the public subnet on availability_zone ap-south-1b
resource "aws_subnet" "public_subnet_ap_south_1b" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "Public ap-south-1b 10.0.2.0/24"
  }
}

#Create the private subnet on availability_zone ap-south-1a
resource "aws_subnet" "private_subnet_ap_south_1a" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "Private ap-south-1a 10.0.1.0/24"
  }
}

#Create the private subnet on availability_zone ap-south-1b
resource "aws_subnet" "private_subnet_ap_south_1b" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "Private ap-south-1b 10.0.4.0/24"
  }
}
//----------------------------------------------------------

//------------------- Internet Gateway ----------------------
# Create the internet gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "Internet Gateway for ${var.vpc_name}"
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
    Name = "Public Route Table"
  }
}

# Associate subnet public_subnet_ap_south_1a to the public_route_table
resource "aws_route_table_association" "public_subnet_ap_south_1a__public_route_table_association" {
  subnet_id = "${aws_subnet.public_subnet_ap_south_1a.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}

# Associate subnet public_subnet_ap_south_1b to the public_route_table
resource "aws_route_table_association" "public_subnet_ap_south_1b__public_route_table_association" {
  subnet_id = "${aws_subnet.public_subnet_ap_south_1b.id}"
  route_table_id = "${aws_route_table.public_route_table.id}"
}
//---------------------------------------------------------------

//--------------------- Security Groups -------------------------
# Create the security group for EC2 instances in public subnet
resource "aws_security_group" "public_security_group" {
  name = "public_security_group"
  description = "This Security Group allows HTTP/HTTPS and SSH connections from anywhere."

  vpc_id="${aws_vpc.vpc.id}"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks =  ["0.0.0.0/0"]
  }

  tags {
    Name = "Public Security Group"
  }
}

# Create the security group for EC2 instances in private subnet
resource "aws_security_group" "private_security_group"{
  name = "private_security_group"
  description = "This Security Group enable MySQL 3306 port, ping and SSH only from the public subnet"

 vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["${aws_subnet.public_subnet_ap_south_1a.cidr_block}","${aws_subnet.public_subnet_ap_south_1b.cidr_block}"]
  }

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["${aws_subnet.public_subnet_ap_south_1a.cidr_block}","${aws_subnet.public_subnet_ap_south_1b.cidr_block}"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${aws_subnet.public_subnet_ap_south_1a.cidr_block}","${aws_subnet.public_subnet_ap_south_1b.cidr_block}"]
  }

  tags {
    Name = "Private Security Group"
  }
}

//-------------------EC2 instances----------------------------------

# Now we will deploy the EC2 instances, but before that we need to create a key pair in order to connect later to the instances via SSH.

# Create application server inside the public subnet
resource "aws_instance" "application_server" {
   ami  = "ami-0889b8a448de4fc44"
   instance_type = "t2.micro"
   key_name = "office"
   subnet_id = "${aws_subnet.public_subnet_ap_south_1a.id}"
   vpc_security_group_ids = ["${aws_security_group.public_security_group.id}"]
   associate_public_ip_address = true
   source_dest_check = false
   user_data = "${file("install.sh")}"

  tags {
    Name = "Application Server"
  }
}

# Create Database server inside the private subnet
resource "aws_instance" "database_server" {
   ami  = "ami-0889b8a448de4fc44"
   instance_type = "t2.micro"
   key_name = "office"
   subnet_id = "${aws_subnet.private_subnet_ap_south_1a.id}"
   vpc_security_group_ids = ["${aws_security_group.private_security_group.id}"]
   associate_public_ip_address = false
   source_dest_check = false

  tags {
    Name = "Database Server"
  }
}
//-------------------------------------------------------------------------------

//------------------------ Load Balancer ----------------------------------------
#Create ELB
resource "aws_elb" "public_load_balancer" {
  name = "public-load-balancer"
  subnets = ["${aws_subnet.public_subnet_ap_south_1a.id}","${aws_subnet.public_subnet_ap_south_1b.id}"]
  security_groups = ["${aws_security_group.public_security_group.id}"]
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:8080/"
  }
  listener {
    lb_protocol = "http"
    lb_port = 80
    instance_protocol = "http"
    instance_port = "8080"
  }
}

//--------------------------- Autoscaling group ---------------------------------
#Create Launch Configuration for application server
resource "aws_launch_configuration" "application_server_launch_config" {
  name = "application_server_launch_config"
  image_id = "ami-0889b8a448de4fc44"
  instance_type = "t2.micro"
  key_name = "office"
  security_groups = ["${aws_security_group.public_security_group.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  
  lifecycle {
    create_before_destroy = true
  }
}

#Create AutoScaling Group
resource "aws_autoscaling_group" "application_server_autoscaling_group" {
  name = "application_server_autoscaling_group"
  
  launch_configuration = "${aws_launch_configuration.application_server_launch_config.id}"
  vpc_zone_identifier = ["${aws_vpc.vpc.id}"]
  availability_zones = ["${aws_subnet.public_subnet_ap_south_1a.availability_zone}","${aws_subnet.public_subnet_ap_south_1b.availability_zone}"]
  
  min_size = 2
  max_size = 3
  
  load_balancers = ["${aws_elb.public_load_balancer.name}"]
  
  health_check_type = "ELB"
  
  tag {
    key = "Name"
    value = "application_server_autoscaling_group"
    propagate_at_launch = true
  }
}



//-------------------------------------------------------------------------------

//--------------- User Output ---------------------------------------------------

output "IP" {
  value       = "${aws_instance.application_server.public_ip}"
  description = "The public IP address of the main server instance."
}

output "DNS" {
  value       = "${aws_instance.application_server.public_dns}"
  description = "The DNS address of the Application server instance."
}