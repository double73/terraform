terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

variable "region" {
  type = string
}
variable "image_id" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "pubkey" {
  type = string
}
variable "dkns_server" {
  type = string
}

provider "aws" {
  profile = "default"
  region  = var.region
}

resource "aws_key_pair" "genian_nac_key_pair" {
  key_name   = "genian_nac-key"
  public_key = var.pubkey
}

resource "aws_instance" "genian_nac_cloud_gateway" {
  ami = var.image_id
  tags = {
    Name = "Genian NAC Cloud Sensor"
  }
  instance_type = var.instance_type
  key_name = "genian_nac-key"
  source_dest_check = false
  vpc_security_group_ids = [
    aws_security_group.allow_ipsec.id,
    aws_security_group.allow_openvpn.id,
  ]
  user_data = <<EOF
#! /bin/bash
CONF=/usr/geni/conf/genian.conf
DKNS_SERVER=${var.dkns_server}
[ -f $CONF ] && EXISTS=`grep DKNS_SERVER $CONF`
if [ "x$EXISTS" = "x" ] ; then
	echo "DKNS_SERVER=$DKNS_SERVER" | tee -a $CONF
else
	sed -i "s|DKNS_SERVER=.*|DKNS_SERVER=$DKNS_SERVER|" $CONF
fi
EOF
}

resource "aws_eip" "lb" {
  instance = aws_instance.genian_nac_cloud_gateway.id
  vpc      = true
  tags = {
    Name = "Genian NAC Cloud Sensor"
  }
}

resource "aws_security_group" "allow_ipsec" {
  name        = "allow_ipsec"
  description = "Allow IPSec inbound traffic"

  ingress {
    description = "ISAKMP"
    from_port   = 500
    to_port     = 501
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NAT Traversal"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ipsec"
  }
}

resource "aws_security_group" "allow_openvpn" {
  name        = "allow_openvpn"
  description = "Allow OpenVPN inbound traffic"

  ingress {
    description = "TLS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "OpenVPN UDP"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_openvpn"
  }
}
