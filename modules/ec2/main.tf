resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  key_name                    = var.keypair_name
  associate_public_ip_address = true

  # added to associate the EC2 instance with the security group
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]

  iam_instance_profile = var.iam_instance_profile

  user_data = var.user_data

  tags = {
    Name = "${var.ec2_instance_name}"
  }
}

#Previous block
resource "aws_security_group" "allow_ssh_http" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.ec2_instance_name}-sg"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  # we are retrieving a specific version of Ubuntu
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  # with a specific virtualization type,
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  #  from a specific AWS account that decided to make the AMI publicly available
  owners = ["099720109477"] # Canonical
}
