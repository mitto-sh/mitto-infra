# Same 5 service repos as prod — images pushed here get pulled by the dev EC2
# instance today, and by ECS later with zero change to the repo names.
resource "aws_ecr_repository" "services" {
  for_each             = toset(["api", "build", "orchestrator", "worker", "dashboard"])
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
