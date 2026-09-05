# Same repos as prod, plus a dev-only "migrate" repo (one-shot DB migration
# image — has no equivalent in prod, which uses a managed Aurora migration
# path instead) — images pushed here get pulled by the dev EC2 instance
# today, and the 6 prod-shared ones by ECS later with zero change to names.
resource "aws_ecr_repository" "services" {
  for_each             = toset(["api", "build", "orchestrator", "worker", "dashboard", "realtime", "migrate"])
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

data "aws_caller_identity" "current" {}
