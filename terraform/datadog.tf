variable "datadog_site" {
  type    = string
  default = "datadoghq.com"
}

variable "datadog_external_id" {
  type      = string
  default   = ""
  sensitive = true
}

# The API key secret you created by hand
data "aws_secretsmanager_secret" "datadog" {
  name = "taskflow/datadog-api-key"
}

# Let the servers read that one secret
resource "aws_iam_role_policy" "datadog_secret" {
  name = "read-datadog-api-key"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = data.aws_secretsmanager_secret.datadog.arn
    }]
  })
}

# Role that lets Datadog read your CloudWatch data (created in the second pass, Part 4)
data "aws_iam_policy_document" "datadog_assume" {
  count = var.datadog_external_id == "" ? 0 : 1

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::464622532012:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.datadog_external_id]
    }
  }
}

resource "aws_iam_role" "datadog_integration" {
  count              = var.datadog_external_id == "" ? 0 : 1
  name               = "DatadogIntegrationRole"
  assume_role_policy = data.aws_iam_policy_document.datadog_assume[0].json
}

resource "aws_iam_role_policy" "datadog_integration" {
  count = var.datadog_external_id == "" ? 0 : 1
  name  = "datadog-read-only"
  role  = aws_iam_role.datadog_integration[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:Get*",
        "cloudwatch:List*",
        "cloudwatch:Describe*",
        "ec2:Describe*",
        "elasticloadbalancing:Describe*",
        "autoscaling:Describe*",
        "rds:Describe*",
        "rds:ListTagsForResource",
        "ecr:Describe*",
        "ecr:List*",
        "tag:GetResources"
      ]
      Resource = "*"
    }]
  })
}