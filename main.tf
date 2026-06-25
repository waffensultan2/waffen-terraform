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

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true
  user_data                   = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y nginx

              # Create index.html with H1 tag in the default NGINX web directory
              echo "<h1>Hello From Ubuntu EC2 Instance!!!</h1>" | sudo tee /var/www/html/index.html

              # Restart NGINX to apply the changes which listens to port 80 by default
              sudo systemctl restart nginx
  EOF

  tags = {
    Name = "${local.team_name}-products-instance"
  }

  # added to associate the EC2 instance with the security group
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "./.ssh/terraform_rsa"
}

resource "local_file" "public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "./.ssh/terraform_rsa.pub"
}

resource "aws_key_pair" "deployer" {
  key_name   = "${local.team_name}-ubuntu-ssh-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

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
    Name = "${local.team_name}-allow-ssh-http"
  }
}
