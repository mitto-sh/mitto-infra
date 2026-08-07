# ── ECR REPOS (Control Plane services) ────────────────────────────────────────
locals {
  ecr_repos = ["api", "build", "orchestrator", "worker", "dashboard"]
}

resource "aws_ecr_repository" "api" {
  name                 = "${local.name}/api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${local.name}-ecr-api" }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last N images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.ecr_image_retention
      }
      action = { type = "expire" }
    }]
  })
}

# Repeat for other services
resource "aws_ecr_repository" "services" {
  for_each             = toset(["build", "orchestrator", "worker", "dashboard"])
  name                 = "${local.name}/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${local.name}-ecr-${each.key}" }
}

resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last N images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.ecr_image_retention
      }
      action = { type = "expire" }
    }]
  })
}

# ── S3 PLATFORM BUCKET (build artifacts, tf plans, static assets) ─────────────
resource "aws_s3_bucket" "platform" {
  bucket        = "${local.name}-platform-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = { Name = "${local.name}-platform-bucket" }
}

resource "aws_s3_bucket_versioning" "platform" {
  bucket = aws_s3_bucket.platform.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "platform" {
  bucket = aws_s3_bucket.platform.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "platform" {
  bucket                  = aws_s3_bucket.platform.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── SECRETS MANAGER ───────────────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "db_url" {
  name                    = "${local.name}/db-url"
  recovery_window_in_days = 0
  tags                    = { Name = "${local.name}-db-url" }
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id = aws_secretsmanager_secret.db_url.id
  secret_string = "postgresql://${var.db_username}:${random_password.db.result}@${aws_rds_cluster.main.endpoint}:5432/${var.db_name}"
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${local.name}/jwt-secret"
  recovery_window_in_days = 0
  tags                    = { Name = "${local.name}-jwt-secret" }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

resource "random_password" "encryption_key" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "encryption_key" {
  name                    = "${local.name}/encryption-key"
  recovery_window_in_days = 0
  tags                    = { Name = "${local.name}-encryption-key" }
}

resource "aws_secretsmanager_secret_version" "encryption_key" {
  secret_id     = aws_secretsmanager_secret.encryption_key.id
  secret_string = random_password.encryption_key.result
}

# GitHub OAuth — populate manually after creating the OAuth App
resource "aws_secretsmanager_secret" "github_oauth" {
  name                    = "${local.name}/github-oauth"
  recovery_window_in_days = 0
  tags                    = { Name = "${local.name}-github-oauth" }
}

resource "aws_secretsmanager_secret_version" "github_oauth" {
  secret_id = aws_secretsmanager_secret.github_oauth.id
  secret_string = jsonencode({
    client_id     = "REPLACE_ME"
    client_secret = "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string] # Don't overwrite manual updates
  }
}

# Terraform Cloud token — populate manually
resource "aws_secretsmanager_secret" "tf_cloud_token" {
  name                    = "${local.name}/tf-cloud-token"
  recovery_window_in_days = 0
  tags                    = { Name = "${local.name}-tf-cloud-token" }
}

resource "aws_secretsmanager_secret_version" "tf_cloud_token" {
  secret_id     = aws_secretsmanager_secret.tf_cloud_token.id
  secret_string = "REPLACE_ME"

  lifecycle {
    ignore_changes = [secret_string]
  }
}
