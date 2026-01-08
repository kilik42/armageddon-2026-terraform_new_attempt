#order of creation:
# 1) IAM Role
# 2) IAM Role Policy Attachment
#   2) Permissions policy
# 3) Instance profile   
# 4) Attach to EC2

# 1) IAM Role (TRUST POLICY: who can assume this role)
resource "aws_iam_role" "ec2_secrets_role" {
  name = "lab-ec2-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}
# 2) IAM Role Policy Attachment (WHAT this role can do)
# 2) Permissions policy (WHAT the role can do)
resource "aws_iam_policy" "read_specific_secret" {
  name        = "lab-read-specific-secret"
  description = "Allow EC2 to read only the lab RDS secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ReadSpecificSecret"
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]

      # IMPORTANT: This ARN must be correct.
      # It usually looks like:
      # arn:aws:secretsmanager:us-east-1:084828593268:secret:lab_1a/rds/mysqlss-Pf83rV
      Resource = "arn:aws:secretsmanager:us-west-2:084828593268:secret:lab_1a/rds/mysqlss-Pf83rV"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_secret_read" {
  role       = aws_iam_role.ec2_secrets_role.name
  policy_arn = aws_iam_policy.read_specific_secret.arn
}

# 3) Instance profile (how EC2 actually gets the role)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "lab-ec2-instance-profile"
  role = aws_iam_role.ec2_secrets_role.name
}

# 4) Attach to EC2
resource "aws_instance" "lab_ec2" {
  # ... ami, subnet_id, vpc_security_group_ids, etc ...

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
}