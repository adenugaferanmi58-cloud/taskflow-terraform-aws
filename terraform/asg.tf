resource "aws_autoscaling_group" "app" {
  name                      = "taskflow-asg"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Servers must not boot before the database and the app files exist
  depends_on = [aws_db_instance.main, aws_s3_object.app_files]

  tag {
    key                 = "Name"
    value               = "taskflow-app"
    propagate_at_launch = true
  }
}

# Adds or removes servers to keep average CPU near 60%
resource "aws_autoscaling_policy" "cpu" {
  name                   = "taskflow-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60
  }
}