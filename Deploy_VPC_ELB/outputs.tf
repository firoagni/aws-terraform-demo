//--------------- User Output ---------------------------------------------------

output "Elastic Load Balancer DNS" {
  value       = "${aws_elb.elb.dns_name}"
  description = "The DNS address of the Application server instance."
}

output "SSH Command to connect Application Server 1" {
  value       = "ssh -i \"${aws_instance.application_server_1.key_name}.pem\" ec2-user@${aws_instance.application_server_1.public_dns}"
  description = "Command to SSH to the application server 1"
}

output "SSH Command to connect Application Server 2" {
  value       = "ssh -i \"${aws_instance.application_server_2.key_name}.pem\" ec2-user@${aws_instance.application_server_2.public_dns}"
  description = "Command to SSH to the application server 2"
}