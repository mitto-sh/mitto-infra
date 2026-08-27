# mitto-infra

Control Plane Infrastructure. Two independent things live here:
- `docker-compose.yml` — the self-hosted / local Control Plane stack (postgres, redis, api, worker, build, orchestrator, realtime, dashboard).
- `terraform/` — AWS resources for the managed Cloud offering (not implemented yet, see below).

## Local Docker Compose (self-hosted mode)

Runs every Control Plane service as a container talking over the Docker network, matching what a self-hosted operator would run in production. Builds and deployed services run as sibling containers on the same Docker daemon via a socket bind-mount (see `mitto-docs/docs/self-hosting.md` for the socket-mount vs. Docker-in-Docker decision).

Requirements: Docker Desktop (or another Docker Engine) running locally, and this repo checked out as a sibling of every other `mitto-*` repo under the same `mitto/` parent directory — the build context for every service is `..` (the shared parent), since each Dockerfile pulls in sibling `mitto-lib-*` packages.

```bash
cd mitto-infra
cp .env.example .env            # fill in JWT_SECRET, ENCRYPTION_KEY, GITHUB_* etc.
mkdir -p secrets
cp /path/to/github-app-private-key.pem secrets/github-app-private-key.pem
docker compose build
docker compose up
```

- Dashboard: http://localhost:4001
- API: http://localhost:4000
- Realtime (live logs): ws://localhost:4104
Postgres and Redis are not published to the host — only reachable inside the compose network (`postgres:5432`, `redis:6379`). To reach either from the host for debugging, `docker compose exec postgres psql -U mitto` / `docker compose exec redis redis-cli`.

`GITHUB_APP_PRIVATE_KEY_PATH` is set inside `docker-compose.yml` to the in-container mount path — the `secrets/` directory is gitignored and never committed.

## AWS (Cloud Managed mode — planned)

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
