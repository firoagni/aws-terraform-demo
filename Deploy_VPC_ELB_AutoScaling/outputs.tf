//--------------- User Output ---------------------------------------------------

output "Elastic Load Balancer DNS" {
  value       = "${aws_elb.public_load_balancer.dns_name}"
  description = "The DNS address of the Application server instance."
}