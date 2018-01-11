provider "aws" {
  shared_credentials_file = "${var.home_dir}/.aws/credentials"
  profile = "${var.aws_profile}"
  region = "${var.aws_region}"
}

# create a vpc for opendj source_ami
resource "aws_vpc" "opendj-source-ami-vpc" {
  cidr_block = "${var.vpc_cidr_block}"
  enable_dns_hostnames = true
  tags {
    Name = "${var.vpc_name}-vpc"
  }
}

# create an internet gateway
resource "aws_internet_gateway" "opendj-source-ami-vpc-igw" {
  vpc_id = "${aws_vpc.opendj-source-ami-vpc.id}"
  tags {
     Name = "opendj-${var.vpc_name}-igw"
  }
}

resource "aws_route_table_association" "public-subnet" {
  subnet_id      = "${aws_subnet.opendj-public-subnet.id}"
  route_table_id = "${aws_route_table.public-subnet.id}"
}
resource "aws_route_table" "public-subnet" {
  vpc_id = "${aws_vpc.opendj-source-ami-vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.opendj-source-ami-vpc-igw.id}"
  }
  tags {
    Name = "${var.vpc_name}-${element(var.availability_zones, 0)}-public-subnet"
  }
}

# create public subnet
resource "aws_subnet" "opendj-public-subnet" {
  vpc_id                  = "${aws_vpc.opendj-source-ami-vpc.id}"
  availability_zone =  "${element(var.availability_zones, 0)}"
  cidr_block              = "${var.public_subnet_cidr_block}"
  map_public_ip_on_launch = true
  tags {
    Name = "${var.vpc_name}-${element(var.availability_zones, 0)}-opendj-subnet"
  }
}

# create security group
resource "aws_security_group" "opendj-source-ami-sg" {
  name        = "${var.opendj_server_name}-source-ami-sg "
  description = "security group for opendj source ami"
  vpc_id      = "${aws_vpc.opendj-source-ami-vpc.id}"
  # inbound ssh access from FYE DC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.feyeeng_cidr_block}"]
  }
  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# create ec2 instance for opendj source ami
resource "aws_instance" "opendj-source-ami-server" {
  ami = "${var.base_ami}"
  availability_zone = "${element(var.availability_zones, 0)}"
  instance_type = "${var.instance_type}"
  key_name = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.opendj-source-ami-sg.id}"]
  subnet_id = "${aws_subnet.opendj-public-subnet.id}"
  associate_public_ip_address = true
  source_dest_check = false
  iam_instance_profile = "opendj-access-role"
  #user_data = "${file("/home/ubuntu/${var.ansible-playbook}")}"
  user_data = "${data.template_file.run-ansible.rendered}"

  tags {
     Name = "${var.opendj_server_name}-source-ami-instance"
  }
}


resource "aws_eip" "opendj-source-ami-eip" {
  instance = "${aws_instance.opendj-source-ami-server.id}"
  vpc = true
  connection {
    host = "${aws_eip.opendj-source-ami-eip.public_ip}"
    user                = "ubuntu"
    timeout = "3m"
    agent = false
    private_key         = "${file(var.private_key)}"
    #key_name = "${aws_key_pair.auth.id}"
  }
  provisioner "file" {
    source      = "./${var.copy_password_file}"
    destination = "/home/ubuntu/${var.copy_password_file}"
  }
  provisioner "file" {
    source      = "./${var.ansible_playbook}"
    destination = "/home/ubuntu/${var.ansible_playbook}"
  }
}

data "template_file" "run-ansible" {
  template = <<-EOF 
              #!/bin/bash
              "ansible-playbook /home/ubuntu/${var.copy_password_file} && ansible-playbook /home/ubuntu/${var.ansible_playbook}"
             EOF
  depends_on =  ["aws_eip.opendj-source-ami-eip"]
}
