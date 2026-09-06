# Invoked by GitHub Actions after a build+push: pulls the new image(s) from ECR
# and restarts the affected service(s). The instance role already carries
# AmazonSSMManagedInstanceCore, so no inbound access is needed.

resource "aws_ssm_document" "deploy" {
  name            = "${local.name}-deploy"
  document_type   = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Pull and restart one Mitto service (or all) from ECR"
    parameters = {
      service = {
        type           = "String"
        description    = "Service name from docker-compose.yml, or 'all'"
        default        = "all"
        allowedPattern = "^[a-z-]+$"
      }
    }
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "redeploy"
      inputs = {
        workingDirectory = "/opt/mitto"
        runCommand = [
          "set -euo pipefail",
          "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.ecr_registry}",
          "SVC='{{ service }}'",
          "if [ \"$SVC\" = all ]; then /usr/local/bin/docker-compose pull && /usr/local/bin/docker-compose up -d; else /usr/local/bin/docker-compose pull \"$SVC\" && /usr/local/bin/docker-compose up -d \"$SVC\"; fi",
          "/usr/local/bin/docker-compose ps",
        ]
      }
    }]
  })
}
