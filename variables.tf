variable "region" {
  description = "AWS region where the resources will be created"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Type of instance to launch"
  default     = "t2.micro"
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI ID for the specified region"
}

variable "key_name" {
  description = "Name of the key pair to use for SSH access"
}

variable "private_key_path" {
  description = "Path to the private key file for SSH access"
}
