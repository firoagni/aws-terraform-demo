//--------------- User Output ---------------------------------------------------

output "Application Server IP" {
  value       = "${aws_instance.application_server.public_ip}"
  description = "The public IP address of the main server instance."
}

output "Application Server DNS" {
  value       = "${aws_instance.application_server.public_dns}"
  description = "The DNS address of the Application server instance."
}

output "SSH Command" {
  value       = "ssh -i \"${aws_instance.application_server.key_name}.pem\" ec2-user@${aws_instance.application_server.public_dns}"
  description = "Command to SSH to the application server"
}