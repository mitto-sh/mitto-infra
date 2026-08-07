# ── ECS CLUSTER ───────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${local.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${local.name}-cluster" }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# ── IAM: ECS TASK EXECUTION ROLE ──────────────────────────────────────────────
resource "aws_iam_role" "ecs_execution" {
  name = "${local.name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow ECS to pull secrets from Secrets Manager
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "secrets-manager-access"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = ["arn:aws:secretsmanager:${var.aws_region}:*:secret:${local.name}/*"]
    }]
  })
}

# ── IAM: ECS TASK ROLE (what the app itself can do) ───────────────────────────
resource "aws_iam_role" "ecs_task" {
  name = "${local.name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_permissions" {
  name = "mitto-api-permissions"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAccess"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability",
                    "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage",
                    "ecr:PutImage", "ecr:InitiateLayerUpload",
                    "ecr:UploadLayerPart", "ecr:CompleteLayerUpload",
                    "ecr:CreateRepository", "ecr:DescribeRepositories"]
        Resource = "*"
      },
      {
        Sid      = "ECSOrchestration"
        Effect   = "Allow"
        Action   = ["ecs:RegisterTaskDefinition", "ecs:DeregisterTaskDefinition",
                    "ecs:CreateService", "ecs:UpdateService", "ecs:DeleteService",
                    "ecs:DescribeServices", "ecs:DescribeTasks",
                    "ecs:ListTasks", "ecs:RunTask", "ecs:StopTask"]
        Resource = "*"
      },
      {
        Sid      = "IAMPassRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [aws_iam_role.ecs_execution.arn, aws_iam_role.ecs_task.arn]
      },
      {
        Sid      = "S3Access"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject",
                    "s3:ListBucket", "s3:CreateBucket"]
        Resource = ["${aws_s3_bucket.platform.arn}", "${aws_s3_bucket.platform.arn}/*",
                    "arn:aws:s3:::${local.name}-sites-*", "arn:aws:s3:::${local.name}-sites-*/*"]
      },
      {
        Sid      = "SecretsAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:CreateSecret",
                    "secretsmanager:UpdateSecret", "secretsmanager:DeleteSecret",
                    "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${local.name}/*"
      },
      {
        Sid      = "SQSAccess"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage",
                    "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
        Resource = aws_sqs_queue.jobs.arn
      },
      {
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream",
                    "logs:PutLogEvents", "logs:DescribeLogStreams",
                    "logs:GetLogEvents", "logs:FilterLogEvents"]
        Resource = "*"
      },
      {
        Sid      = "Route53"
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets",
                    "route53:GetHostedZone"]
        Resource = "arn:aws:route53:::hostedzone/${aws_route53_zone.main.zone_id}"
      },
      {
        Sid      = "ACM"
        Effect   = "Allow"
        Action   = ["acm:RequestCertificate", "acm:DescribeCertificate",
                    "acm:DeleteCertificate", "acm:AddTagsToCertificate"]
        Resource = "*"
      },
      {
        Sid      = "CloudFront"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateDistribution", "cloudfront:UpdateDistribution",
                    "cloudfront:DeleteDistribution", "cloudfront:GetDistribution",
                    "cloudfront:CreateInvalidation"]
        Resource = "*"
      },
      {
        Sid      = "RDSProvisioning"
        Effect   = "Allow"
        Action   = ["rds:CreateDBCluster", "rds:DeleteDBCluster",
                    "rds:DescribeDBClusters", "rds:ModifyDBCluster",
                    "rds:CreateDBInstance", "rds:DeleteDBInstance"]
        Resource = "*"
      }
    ]
  })
}

# ── CLOUDWATCH LOG GROUP ───────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "api" {
  name              = "/mitto/${var.environment}/api"
  retention_in_days = 30
  tags              = { Name = "${local.name}-api-logs" }
}

# ── ECS TASK DEFINITION ────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "api" {
  family                   = "${local.name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.api_cpu
  memory                   = var.api_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "api"
    image     = "${aws_ecr_repository.api.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]

    secrets = [
      { name = "DATABASE_URL",         valueFrom = "${aws_secretsmanager_secret.db_url.arn}" },
      { name = "JWT_SECRET",           valueFrom = "${aws_secretsmanager_secret.jwt_secret.arn}" },
      { name = "ENCRYPTION_KEY",       valueFrom = "${aws_secretsmanager_secret.encryption_key.arn}" },
      { name = "GITHUB_CLIENT_ID",     valueFrom = "${aws_secretsmanager_secret.github_oauth.arn}:client_id::" },
      { name = "GITHUB_CLIENT_SECRET", valueFrom = "${aws_secretsmanager_secret.github_oauth.arn}:client_secret::" },
    ]

    environment = [
      { name = "NODE_ENV",        value = var.environment },
      { name = "PORT",            value = "3000" },
      { name = "REDIS_URL",       value = "redis://${aws_elasticache_serverless_cache.redis.endpoint[0].address}:6379" },
      { name = "AWS_REGION",      value = var.aws_region },
      { name = "PLATFORM_DOMAIN", value = "https://${var.domain}" },
      { name = "ECR_REGISTRY",    value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com" },
      { name = "TF_CLOUD_ORG",    value = "mitto-sh" },
      { name = "HOSTED_ZONE_ID",  value = aws_route53_zone.main.zone_id },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.api.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "api"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:3000/healthz || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = { Name = "${local.name}-api-task" }
}

data "aws_caller_identity" "current" {}

# ── ECS SERVICE ────────────────────────────────────────────────────────────────
resource "aws_ecs_service" "api" {
  name            = "${local.name}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener_rule.api]

  lifecycle {
    ignore_changes = [task_definition] # CI/CD will update this
  }

  tags = { Name = "${local.name}-api-service" }
}
