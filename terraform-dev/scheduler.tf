# Auto shutdown: stop every night at `shutdown_hour`, start Mon-Fri at `startup_hour`.
# No start event fires Sat/Sun, so the Friday-night stop keeps the instance off
# through the whole weekend — one pair of schedules covers both cases.
# No Lambda needed: EventBridge Scheduler calls the EC2 API directly.

resource "aws_iam_role" "scheduler" {
  name = "${local.name}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_ec2" {
  name = "ec2-start-stop"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:StopInstances", "ec2:StartInstances"]
      Resource = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.app.id}"
    }]
  })
}

resource "aws_scheduler_schedule" "stop_nightly" {
  name = "${local.name}-stop-nightly"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(0 ${var.shutdown_hour} * * ? *)"
  schedule_expression_timezone = var.schedule_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ InstanceIds = [aws_instance.app.id] })
  }
}

resource "aws_scheduler_schedule" "start_weekdays" {
  name = "${local.name}-start-weekdays"

  flexible_time_window {
    mode = "OFF"
  }

  # MON-FRI only — instance stays stopped through Sat/Sun
  schedule_expression          = "cron(0 ${var.startup_hour} ? * MON-FRI *)"
  schedule_expression_timezone = var.schedule_timezone

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ InstanceIds = [aws_instance.app.id] })
  }
}
