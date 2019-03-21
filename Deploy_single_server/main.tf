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
#           Resources
#
###############################################################

//--------------------- Security Groups -------------------------
# Create the security group for EC2 instances in public subnet
resource "aws_security_group" "public_security_group" {
  name = "public_security_group"
  description = "This Security Group allows HTTP/HTTPS and SSH connections from anywhere."

  // ------------ Inbound Rules -----------------------------
  ingress {
    description = "Allow HTTP from anywhere"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from anywhere"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
  /*
    NOTE on Egress rules: 
    By default, AWS creates an ALLOW ALL egress rule when creating a new Security Group inside of a VPC. 
    When creating a new Security Group inside a VPC, Terraform will remove this default rule, 
    and require you specifically re-create it if you desire that rule.
   */ 
  egress {
    description = "Allow All traffic to pass through"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } 
  //---------------------------------------------------------
  
  tags {
    Name = "Public SG"
  }
}

//-------------------EC2 instances----------------------------------
# Create application server instance
resource "aws_instance" "application_server" {
   ami  = "${var.ami}"
   instance_type = "${var.instance_type_application_server}"
   key_name = "${var.ssh_key_name}"
   vpc_security_group_ids = ["${aws_security_group.public_security_group.id}"]
   //associate_public_ip_address = true //Important 
   source_dest_check = false
   user_data = "${file("install.sh")}" //"file" is a function that returns the content of the file that is passed to it

  /*
  instead of user_data, you can achieve the same using "remote-exec" "provisioner"
  Advantage of using user_data over provisioner: You can use user_data in autoscaling group but you cannot use "remote-exec" with it
  
  # To use a provisioner, you need to define a "connection"
  # The connection block tells our provisioner how to communicate with the instance
  connection {
    user = "ec2-user"
    private_key = "${file("D:\\Downloads\\MyEC2Key.pem")}" //"file" is a function that returns the content of the file that is passed to it
  }

  # After the creation of the instance, 
  # remote-exec provisioner logs in it using the "connection" block data
  # and executes commands in that instance
  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo yum install -y httpd",
      "sudo chmod 777 /var/www/html",
      "echo Application Server is up and Running >> /var/www/html/index.html",
      "sudo service httpd start",
      "sudo chkconfig httpd on",
      "sudo service httpd status"
    ] 
  } */

  tags {
    Name = "Application Server"
  }
}

//-------------------------------------------------------------------------------

