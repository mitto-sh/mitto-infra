# ── ALB ────────────────────────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "ALB — allow HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-alb-sg" }
}

# ── ECS TASKS (API / Worker / etc.) ───────────────────────────────────────────
resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name}-ecs-tasks-sg"
  description = "ECS tasks — only allow traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-ecs-tasks-sg" }
}

# ── RDS ────────────────────────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "RDS — only allow traffic from ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  tags = { Name = "${local.name}-rds-sg" }
}

# ── ELASTICACHE (Redis) ────────────────────────────────────────────────────────
resource "aws_security_group" "redis" {
  name        = "${local.name}-redis-sg"
  description = "Redis — only allow traffic from ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  tags = { Name = "${local.name}-redis-sg" }
}

# ── VPC ENDPOINTS ──────────────────────────────────────────────────────────────
resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name}-vpc-endpoints-sg"
  description = "VPC Interface Endpoints — allow HTTPS from private subnets"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.private_subnets
  }

  tags = { Name = "${local.name}-vpc-endpoints-sg" }
}
