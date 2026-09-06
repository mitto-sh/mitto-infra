# mitto-agent

Runs a Mitto deploy target on your own VM or laptop — no cloud account. The agent
opens an outbound WebSocket to Mitto; nothing connects in.

## What it runs

| Container | Role |
|-----------|------|
| `agent` | `mitto-orchestrator` in `RUN_MODE=agent` — holds the outbound connection, runs `docker` deploys locally, relays logs |
| `build` | `mitto-build` — clones the repo and builds the image on this machine |
| `redis` | local pub/sub between `build` and `agent` |

`agent` and `build` mount `/var/run/docker.sock` (single-operator machine — same
trade-off as the self-hosted control plane, see `mitto-docs/docs/self-hosting.md`).

## Install

1. In Mitto: Account Settings → Provider → Self-Hosted VM → create an agent, copy the `mag_…` token.
2. On the VM:

```sh
curl -fsSL https://get.mitto.sh/agent | sh
```

or manually:

```sh
mkdir -p ~/.mitto-agent && cd ~/.mitto-agent
curl -fsSL https://raw.githubusercontent.com/mitto-sh/mitto-infra/main/agent/docker-compose.yml -o docker-compose.yml
echo "MITTO_AGENT_TOKEN=mag_xxx" > .env
docker compose up -d
```

## Configuration (`.env`)

| Variable | Default |
|----------|---------|
| `MITTO_AGENT_TOKEN` | — (required) |
| `MITTO_API_URL` | `https://api.dhinrichs.dev` |
| `MITTO_REALTIME_URL` | `wss://realtime.dhinrichs.dev` |
| `MITTO_ORCHESTRATOR_IMAGE` / `MITTO_BUILD_IMAGE` | `ghcr.io/mitto-sh/*:latest` |
