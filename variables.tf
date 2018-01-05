variable "aws_region" {}

variable "vpc_name" {}

variable "feyeeng_cidr_block" {}

variable "vpc_cidr_block" {}

variable "base_ami" {}

variable "private_key" {}

variable "public_subnet_cidr_block" {}

variable "opendj_server_name" {}

variable "instance_type" {}

variable "aws_profile" {}

variable "home_dir" {}

variable "key_name" {}

variable "ansible-playbook" {}

variable "availability_zones" {
  type        = "list"
}

variable "public_key_path" {}
