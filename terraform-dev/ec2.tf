data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_key_pair" "dev" {
  key_name   = "${local.name}-key"
  public_key = var.ssh_public_key
}

# ── IAM ────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "ec2" {
  name = "${local.name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ec2_ecr_pull" {
  name = "ecr-pull"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ── SECRETS (generated here, written to the instance's .env at boot) ─────────
resource "random_password" "db" {
  length  = 32
  special = false
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "random_password" "encryption_key" {
  length  = 64
  special = false
}

# ── INSTANCE ───────────────────────────────────────────────────────────────────
locals {
  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  env_file = <<-EOT
    NODE_ENV=development
    DATABASE_URL=postgres://mitto:${random_password.db.result}@postgres:5432/mitto
    REDIS_URL=redis://redis:6379
    JWT_SECRET=${random_password.jwt_secret.result}
    JWT_EXPIRES_IN=7d
    ENCRYPTION_KEY=${random_password.encryption_key.result}
    AWS_REGION=${var.aws_region}
    ECR_REGISTRY=${local.ecr_registry}
    PLATFORM_DOMAIN=https://api.${var.domain}
    DASHBOARD_URL=https://app.${var.domain}
    GITHUB_CLIENT_ID=${var.github_client_id}
    GITHUB_CLIENT_SECRET=${var.github_client_secret}
    GITHUB_APP_ID=${var.github_app_id}
    GITHUB_APP_SLUG=${var.github_app_slug}
    GITHUB_APP_CLIENT_ID=${var.github_app_client_id}
    GITHUB_APP_CLIENT_SECRET=${var.github_app_client_secret}
    GITHUB_APP_PRIVATE_KEY_PATH=/app/secrets/github-app-private-key.pem
    GITLAB_CLIENT_ID=${var.gitlab_client_id}
    GITLAB_CLIENT_SECRET=${var.gitlab_client_secret}
    MITTO_BUILD_URL=http://build:3001
    MITTO_ORCHESTRATOR_URL=http://orchestrator:3003
    DEPLOY_MODE=docker
    DEPLOY_HOST=host.docker.internal
  EOT

  docker_compose = <<-EOT
    services:
      postgres:
        image: postgres:16-alpine
        restart: unless-stopped
        environment:
          POSTGRES_USER: mitto
          POSTGRES_PASSWORD: ${random_password.db.result}
          POSTGRES_DB: mitto
        volumes:
          - pgdata:/var/lib/postgresql/data
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U mitto"]
          interval: 5s
          timeout: 5s
          retries: 5

      redis:
        image: redis:7-alpine
        restart: unless-stopped
        volumes:
          - redisdata:/data
        healthcheck:
          test: ["CMD", "redis-cli", "ping"]
          interval: 5s
          timeout: 5s
          retries: 5

      api:
        image: ${local.ecr_registry}/${local.name}/api:latest
        restart: unless-stopped
        env_file: .env
        environment:
          PORT: 4000
        ports:
          - "4000:4000"
        volumes:
          - ./secrets:/app/secrets:ro
        depends_on:
          postgres:
            condition: service_healthy
          redis:
            condition: service_healthy

      worker:
        image: ${local.ecr_registry}/${local.name}/worker:latest
        restart: unless-stopped
        env_file: .env
        environment:
          PORT: 3002
        depends_on:
          postgres:
            condition: service_healthy
          redis:
            condition: service_healthy

      build:
        image: ${local.ecr_registry}/${local.name}/build:latest
        restart: unless-stopped
        env_file: .env
        environment:
          PORT: 3001
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock
          - ./secrets:/app/secrets:ro
        depends_on:
          redis:
            condition: service_healthy

      orchestrator:
        image: ${local.ecr_registry}/${local.name}/orchestrator:latest
        restart: unless-stopped
        env_file: .env
        environment:
          PORT: 3003
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock
        extra_hosts:
          - "host.docker.internal:host-gateway"
        depends_on:
          redis:
            condition: service_healthy

      realtime:
        image: ${local.ecr_registry}/${local.name}/realtime:latest
        restart: unless-stopped
        env_file: .env
        environment:
          PORT: 4104
        ports:
          - "4104:4104"
        depends_on:
          redis:
            condition: service_healthy

      dashboard:
        image: ${local.ecr_registry}/${local.name}/dashboard:latest
        restart: unless-stopped
        ports:
          - "4001:4001"
        depends_on:
          - api

    volumes:
      pgdata:
      redisdata:
  EOT

  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    dnf install -y docker
    systemctl enable --now docker
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    mkdir -p /opt/mitto/secrets
    cat > /opt/mitto/.env <<'ENVEOF'
    ${local.env_file}
    ENVEOF

    cat > /opt/mitto/docker-compose.yml <<'COMPOSEEOF'
    ${local.docker_compose}
    COMPOSEEOF

    cat > /opt/mitto/secrets/github-app-private-key.pem <<'PEMEOF'
    ${var.github_app_private_key}
    PEMEOF
    chmod 600 /opt/mitto/secrets/github-app-private-key.pem

    aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin ${local.ecr_registry} || true

    cd /opt/mitto && /usr/local/bin/docker-compose up -d || true
  EOT
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = aws_key_pair.dev.key_name
  user_data              = local.user_data

  root_block_device {
    volume_type = "gp3"
    volume_size = var.ebs_size_gb
  }

  tags = { Name = "${local.name}-app" }
}
