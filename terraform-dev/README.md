# mitto-infra — terraform-dev

Ambiente de desarrollo barato para el Control Plane: **EC2 t3.small + Docker Compose**,
en vez de ECS Fargate + Aurora Serverless v2 + ElastiCache Serverless (arquitectura de
`../terraform`, ~$131/mes).

## Qué provisiona

- VPC propia (`10.1.0.0/16`), solo subnets públicas — **sin NAT Gateway** (ahorra ~$32/mes)
- 1x EC2 `t3.small` corriendo Docker Compose (postgres + redis + api)
- ALB con TLS (mismo patrón que prod, para que migrar a ECS después no requiera cambios de código)
- Route 53 + ACM wildcard cert para `dhinrichs.dev`
- ECR (mismos 5 repos que prod: api/build/orchestrator/worker/dashboard)
- Apagado automático (EventBridge Scheduler, sin Lambda): stop diario, start Lun-Vie → apagado
  todo el fin de semana

**Costo estimado:** ~$34/mes si corriera 24/7, **~$5-10/mes efectivo** con el apagado automático
(ver `docs/costs.md` en `mitto-docs`). Horario configurable con `shutdown_hour` / `startup_hour` /
`schedule_timezone` en `variables.tf` (default: 23:00-09:00 `America/Santiago`).

## Por qué existe esta carpeta separada

El código en `../terraform` es la arquitectura de producción correcta y no se debe tocar.
Este stack es un ambiente aparte (workspace de Terraform Cloud distinto: `mitto-infra-dev`)
para desarrollar sin quemar el presupuesto de $150 en ~1 mes.

⚠️ **Este stack crea la hosted zone de `dhinrichs.dev`.** Cuando llegue el momento de aplicar
`../terraform` (prod), hay que decidir cómo se comparte/migra la zona — no aplicar ambos
stacks con el mismo dominio sin resolver esto antes.

## Getting Started

```bash
cp terraform.tfvars.example terraform.tfvars
# completar ssh_public_key y ssh_allowed_cidr (tu IP, no 0.0.0.0/0)

terraform init
terraform plan
terraform apply
```
