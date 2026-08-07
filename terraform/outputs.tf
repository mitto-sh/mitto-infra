# ── DNS ────────────────────────────────────────────────────────────────────────
output "route53_zone_id" {
  description = "Hosted zone ID — needed for DNS record creation"
  value       = aws_route53_zone.main.zone_id
}

output "route53_nameservers" {
  description = "⚠️  Point your domain registrar to these nameservers"
  value       = aws_route53_zone.main.name_servers
}

# ── ALB ────────────────────────────────────────────────────────────────────────
output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "api_url" {
  description = "API base URL"
  value       = "https://api.${var.domain}"
}

# ── ECS ────────────────────────────────────────────────────────────────────────
output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

# ── ECR ────────────────────────────────────────────────────────────────────────
output "ecr_api_url" {
  description = "ECR repository URL for the API image"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_registry" {
  description = "ECR registry base URL"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# ── DATABASE ───────────────────────────────────────────────────────────────────
output "db_endpoint" {
  description = "RDS cluster writer endpoint"
  value       = aws_rds_cluster.main.endpoint
  sensitive   = true
}

output "db_secret_arn" {
  description = "Secrets Manager ARN for the DB connection URL"
  value       = aws_secretsmanager_secret.db_url.arn
}

# ── REDIS ──────────────────────────────────────────────────────────────────────
output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = aws_elasticache_serverless_cache.redis.endpoint[0].address
  sensitive   = true
}

# ── S3 ─────────────────────────────────────────────────────────────────────────
output "platform_bucket" {
  description = "Platform S3 bucket name"
  value       = aws_s3_bucket.platform.bucket
}

# ── NETWORKING ─────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

# ── NEXT STEPS ─────────────────────────────────────────────────────────────────
output "next_steps" {
  description = "Manual steps required after apply"
  value = <<-EOT

    ✅ Infrastructure deployed. Manual steps required:

    1. NAMESERVERS — Go to your domain registrar and set these nameservers for dhinrichs.dev:
       ${join("\n       ", aws_route53_zone.main.name_servers)}

    2. GITHUB OAUTH — Create an OAuth App at https://github.com/settings/developers
       Homepage URL:     https://${var.domain}
       Callback URL:     https://api.${var.domain}/auth/github/callback
       Then update the secret: aws secretsmanager put-secret-value \
         --secret-id ${aws_secretsmanager_secret.github_oauth.name} \
         --secret-string '{"client_id":"YOUR_ID","client_secret":"YOUR_SECRET"}'

    3. TERRAFORM CLOUD TOKEN — Generate at https://app.terraform.io/app/settings/tokens
       Then update: aws secretsmanager put-secret-value \
         --secret-id ${aws_secretsmanager_secret.tf_cloud_token.name} \
         --secret-string 'YOUR_TOKEN'

    4. PUSH API IMAGE — Build and push mitto-api to ECR:
       aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
       docker build -t ${aws_ecr_repository.api.repository_url}:latest ./mitto-api
       docker push ${aws_ecr_repository.api.repository_url}:latest

  EOT
}
