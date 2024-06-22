variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "vpc_name" {
  type    = string
  default = "jenkins_prod"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  default = {
    "public_subnet_1" = 1
  }
}

variable "variables_sub_cidr" {
  description = "CIDR Block for the Variables Subnet"
  type        = string
  default     = "10.0.202.0/24"
}
variable "variables_sub_az" {
  description = "Availability Zone used Variables Subnet"
  type        = string
  default     = "us-east-1a"
}
variable "variables_sub_auto_ip" {
  description = "Set Automatic IP Assigment for Variables Subnet"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment for deployment"
  type        = string
  default     = "prod"
}

variable "jenkins_user_data_file" {
  description = "Path to the user data file for bootstrapping the Jenkins EC2 instance"
  type        = string
  default     = "jenkins_userdata.sh"
}

variable "my_ip" {
  description = "My public IP address for SSH access"
  type        = string
  default     = "0.0.0.0/32" # Replace with your IP
}