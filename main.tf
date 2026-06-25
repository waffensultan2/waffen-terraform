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
                apt update -y
                apt install -y python3 python3-pip git nginx

                # Clone your repo
                git clone ${local.flask_github_repo} /home/ubuntu/app
                cd /home/ubuntu/app

                export AWS_REGION=${local.assigned_aws_region}
                export DYNAMODB_TABLE_NAME=${aws_dynamodb_table.products_table.name}

                # Install Python dependencies
                pip3 install --upgrade pip
                pip3 install -r requirements.txt

                # Start the Flask app using nohup (assumes app.py runs on 0.0.0.0:5000)
                nohup python3 app.py > app.log 2>&1 &

                # Configure NGINX to proxy traffic to the Flask app
                tee /etc/nginx/sites-available/default > /dev/null << EOL
                server {
                    listen 80 default_server;
                    listen [::]:80 default_server;

                    location / {
                        proxy_pass http://127.0.0.1:5000;
                        proxy_set_header Host \$host;
                        proxy_set_header X-Real-IP \$remote_addr;
                        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                        proxy_set_header X-Forwarded-Proto \$scheme;
                    }
                }
                EOL

                # Restart NGINX
                systemctl restart nginx
    EOF

  tags = {
    Name = "${local.team_name}-products-instance"
  }

  # added to associate the EC2 instance with the security group
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
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

resource "aws_dynamodb_table" "products_table" {
  name         = "${local.team_name}-products-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "product_id"

  attribute {
    name = "product_id"
    type = "S"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }

  tags = {
    Name        = "${local.team_name}-products-table"
    Environment = "production"
  }
}

data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${local.team_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}

data "aws_iam_policy_document" "dynamodb_access_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:Scan"
    ]
    resources = [
      aws_dynamodb_table.products_table.arn
    ]
  }
}

resource "aws_iam_role_policy" "dynamodb_access" {
  name   = "${local.team_name}-dynamodb-access"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.dynamodb_access_policy.json
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${local.team_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
