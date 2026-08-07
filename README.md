# mitto-infra

Control Plane Infrastructure — AWS resources that run the Mitto platform itself.

## What this provisions
- VPC (3 public + 3 private subnets, 3 AZs)
- ECS Cluster (Fargate) — runs all Control Plane services
- ALB — HTTPS termination for API and Dashboard
- RDS Aurora Serverless v2 (PostgreSQL) — Control Plane database
- ElastiCache (Redis) — job queue + cache
- SQS — async job queue
- ECR — container registry for platform images
- Secrets Manager — platform secrets
- S3 — build artifacts and static assets
- Route 53 + ACM — wildcard DNS and TLS

## Requirements
- Terraform >= 1.6
- AWS credentials with AdministratorAccess (initial bootstrap only)

## Getting Started
```bash
cd terraform
terraform init
terraform plan
terraform apply
```
