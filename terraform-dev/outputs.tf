output "instance_public_ip" {
  description = "EC2 public IP (for direct SSH)"
  value       = aws_instance.app.public_ip
}

output "ssh_command" {
  description = "SSH into the dev instance"
  value       = "ssh ec2-user@${aws_instance.app.public_ip}"
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "api_url" {
  value = "https://api.${var.domain}"
}

output "app_url" {
  value = "https://app.${var.domain}"
}

output "realtime_url" {
  value = "wss://realtime.${var.domain}"
}

output "route53_nameservers" {
  description = "Point your domain registrar to these nameservers"
  value       = aws_route53_zone.main.name_servers
}

output "ecr_repository_urls" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "codeartifact_npm_registry" {
  description = "npm registry endpoint for @mitto-sh/* — run: aws codeartifact login --tool npm --domain mitto --repository libs"
  value       = "https://${aws_codeartifact_domain.mitto.domain}-${data.aws_caller_identity.current.account_id}.d.codeartifact.${var.aws_region}.amazonaws.com/npm/${aws_codeartifact_repository.libs.repository}/"
}

output "codeartifact_policy_arns" {
  description = "Attach to CI roles: read for service builds, publish for the lib publish workflow"
  value = {
    read    = aws_iam_policy.codeartifact_read.arn
    publish = aws_iam_policy.codeartifact_publish.arn
  }
}

output "github_ci_role_arn" {
  description = "Set as GitHub Actions org vars CODEARTIFACT_PUBLISH_ROLE_ARN and DEPLOY_ROLE_ARN"
  value       = aws_iam_role.ci.arn
}

output "ssm_deploy_document" {
  description = "SSM document name for deploy-service.yml"
  value       = aws_ssm_document.deploy.name
}

output "instance_id" {
  description = "EC2 instance id for aws ssm send-command --instance-ids"
  value       = aws_instance.app.id
}

output "github_actions_org_vars" {
  description = "Values to set as GitHub Actions org/repo variables"
  value = {
    AWS_ACCOUNT_ID                = data.aws_caller_identity.current.account_id
    AWS_REGION                    = var.aws_region
    CODEARTIFACT_PUBLISH_ROLE_ARN = aws_iam_role.ci.arn
    DEPLOY_ROLE_ARN               = aws_iam_role.ci.arn
    DEPLOY_INSTANCE_ID            = aws_instance.app.id
    DEPLOY_SSM_DOCUMENT           = aws_ssm_document.deploy.name
    ECR_REGISTRY                  = local.ecr_registry
  }
}

output "auto_shutdown_schedule" {
  description = "Apagado automático configurado"
  value       = "Stop diario a las ${var.shutdown_hour}:00, start Lun-Vie a las ${var.startup_hour}:00 (${var.schedule_timezone}) — apagado todo el fin de semana"
}

output "next_steps" {
  value = <<-EOT

    ✅ Dev infra deployed. Apagado automático activo → ~$5-10/mes efectivo
       (stop diario ${var.shutdown_hour}:00, start Lun-Vie ${var.startup_hour}:00, ${var.schedule_timezone}).

    1. NAMESERVERS — apunta dhinrichs.dev a:
       ${join("\n       ", aws_route53_zone.main.name_servers)}

    2. GitHub OAuth App — el callback URL registrado en GitHub debe ser:
       https://api.${var.domain}/auth/github/callback
       (si sigue apuntando a localhost, el login va a fallar)

    3. Buildear y pushear los 6 servicios a ECR — desde la raíz del repo (mitto/,
       no mitto-infra/), porque cada Dockerfile hace multi-stage build contra
       los mitto-lib-* hermanos:
       aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.ecr_registry}
       for svc in api worker build orchestrator realtime; do
         docker build -f mitto-$svc/Dockerfile -t ${local.ecr_registry}/${local.name}/$svc:latest .
         docker push ${local.ecr_registry}/${local.name}/$svc:latest
       done
       docker build -f mitto-dashboard/Dockerfile \
         --build-arg NEXT_PUBLIC_API_URL=https://api.${var.domain} \
         --build-arg NEXT_PUBLIC_REALTIME_URL=wss://realtime.${var.domain} \
         -t ${local.ecr_registry}/${local.name}/dashboard:latest .
       docker push ${local.ecr_registry}/${local.name}/dashboard:latest

    4. Los contenedores ya están definidos en /opt/mitto/docker-compose.yml (escrito al
       boot). Una vez pusheadas las imágenes, SSH al instance y:
       cd /opt/mitto && docker-compose pull && docker-compose up -d

    5. Si necesitas la instancia corriendo fuera del horario Lun-Vie ${var.startup_hour}-${var.shutdown_hour}h,
       arrancala manualmente: aws ec2 start-instances --instance-ids ${aws_instance.app.id}
  EOT
}
