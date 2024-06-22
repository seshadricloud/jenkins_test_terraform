output "jenkins_server_public_ip" {
  description = "The public IP address of the Jenkins server with port 8080 appended."
  value       = "${aws_instance.jenkins_server.public_ip}:8080"
}