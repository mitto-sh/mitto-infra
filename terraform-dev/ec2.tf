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
  env_file = <<-EOT
    NODE_ENV=development
    PORT=3000
    DATABASE_URL=postgres://mitto:${random_password.db.result}@postgres:5432/mitto
    REDIS_URL=redis://redis:6379
    JWT_SECRET=${random_password.jwt_secret.result}
    JWT_EXPIRES_IN=7d
    AWS_REGION=${var.aws_region}
    ECR_REGISTRY=${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
    PLATFORM_DOMAIN=${var.domain}
    ENCRYPTION_KEY=${random_password.encryption_key.result}
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

      redis:
        image: redis:7-alpine
        restart: unless-stopped

      # Uncomment once mitto-api has been built and pushed to ECR:
      # api:
      #   image: ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.name}/api:latest
      #   restart: unless-stopped
      #   env_file: .env
      #   ports:
      #     - "3000:3000"
      #   depends_on:
      #     - postgres
      #     - redis

    volumes:
      pgdata:
  EOT

  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    dnf install -y docker
    systemctl enable --now docker
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    mkdir -p /opt/mitto
    cat > /opt/mitto/.env <<'ENVEOF'
    ${local.env_file}
    ENVEOF

    cat > /opt/mitto/docker-compose.yml <<'COMPOSEEOF'
    ${local.docker_compose}
    COMPOSEEOF

    aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com || true

    cd /opt/mitto && /usr/local/bin/docker-compose up -d
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
