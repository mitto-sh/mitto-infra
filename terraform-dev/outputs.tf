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

output "route53_nameservers" {
  description = "Point your domain registrar to these nameservers"
  value       = aws_route53_zone.main.name_servers
}

output "ecr_repository_urls" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
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

    2. Buildear y pushear mitto-api a ECR:
       aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
       docker build -t ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.name}/api:latest ./mitto-api
       docker push ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.name}/api:latest

    3. SSH al instance y descomentar el servicio "api" en /opt/mitto/docker-compose.yml, luego:
       cd /opt/mitto && docker-compose up -d

    4. Si necesitas la instancia corriendo fuera del horario Lun-Vie ${var.startup_hour}-${var.shutdown_hour}h,
       arrancala manualmente: aws ec2 start-instances --instance-ids ${aws_instance.app.id}
  EOT
}
