# Find the newest official Ubuntu 24.04 image
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical, the company behind Ubuntu

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# The launch template: the recipe for every server
resource "aws_launch_template" "app" {
  name_prefix   = "taskflow-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    bucket      = aws_s3_bucket.app.id
    secret_name = aws_secretsmanager_secret.db.name
    region      = "us-east-1"
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "taskflow-app" }
  }
}