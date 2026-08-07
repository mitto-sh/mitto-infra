# ── RDS SUBNET GROUP ──────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = "${local.name}-db-subnet-group" }
}

# ── RDS AURORA SERVERLESS V2 (Control Plane DB) ───────────────────────────────
resource "random_password" "db" {
  length  = 32
  special = false # avoid shell-escaping issues
}

resource "aws_rds_cluster" "main" {
  cluster_identifier     = "${local.name}-db"
  engine                 = "aurora-postgresql"
  engine_mode            = "provisioned"
  engine_version         = "15.4"
  database_name          = var.db_name
  master_username        = var.db_username
  master_password        = random_password.db.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true # set false for prod
  storage_encrypted      = true
  deletion_protection    = false # set true for prod

  serverlessv2_scaling_configuration {
    min_capacity = var.db_min_acu
    max_capacity = var.db_max_acu
  }

  tags = { Name = "${local.name}-db" }
}

resource "aws_rds_cluster_instance" "main" {
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  tags = { Name = "${local.name}-db-instance" }
}

# ── ELASTICACHE SERVERLESS (Redis) ────────────────────────────────────────────
resource "aws_elasticache_serverless_cache" "redis" {
  engine = "redis"
  name   = "${local.name}-redis"

  cache_usage_limits {
    data_storage {
      maximum = 1
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = 1000
    }
  }

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.redis.id]

  tags = { Name = "${local.name}-redis" }
}

# ── SQS QUEUE (async jobs) ────────────────────────────────────────────────────
resource "aws_sqs_queue" "jobs" {
  name                      = "${local.name}-jobs"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 86400 # 1 day
  receive_wait_time_seconds = 10    # long polling
  visibility_timeout_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.jobs_dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Name = "${local.name}-jobs" }
}

resource "aws_sqs_queue" "jobs_dlq" {
  name                      = "${local.name}-jobs-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = { Name = "${local.name}-jobs-dlq" }
}
