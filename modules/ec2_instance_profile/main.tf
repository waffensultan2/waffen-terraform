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

data "aws_iam_policy_document" "ec2_access_policy" {
  dynamic "statement" {
    for_each = var.iam_policies
    content {
      effect    = statement.value["effect"]
      actions   = statement.value["actions"]
      resources = statement.value["resources"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.profile_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}


resource "aws_iam_role_policy" "dynamodb_access" {
  name   = "${var.profile_name}-dynamodb-access"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.ec2_access_policy.json
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.profile_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
