# Trust policy: only EC2 may use this role
resource "aws_iam_role" "app" {
  name = "taskflow-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { ManagedBy = "Terraform" }
}

# Permission: read objects from our one bucket
resource "aws_iam_role_policy" "s3_read" {
  name = "taskflow-s3-read"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.app.arn,
        "${aws_s3_bucket.app.arn}/*"
      ]
    }]
  })
}

# AWS-managed policy: lets Session Manager open a shell, no SSH needed
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# The wrapper that attaches the role to EC2 instances
resource "aws_iam_instance_profile" "app" {
  name = "taskflow-app-profile"
  role = aws_iam_role.app.name
}
# Permission: read ONLY the database secret
resource "aws_iam_role_policy" "secret_read" {
  name = "taskflow-secret-read"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.db.arn
    }]
  })
}