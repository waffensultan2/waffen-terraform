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

  # FILL THIS UP
  # change with your team name
  tags = {
    Name = "${local.team_name}-products-instance"
  }
}
