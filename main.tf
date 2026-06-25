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

module "ec2_web_instance" {
  source               = "./modules/ec2"
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  keypair_name         = aws_key_pair.deployer.key_name
  user_data            = <<-EOF
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
  ec2_instance_name    = "${local.team_name}-products-instance"
}
