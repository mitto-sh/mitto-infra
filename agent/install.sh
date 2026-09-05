#!/usr/bin/env sh
set -eu

RAW_BASE="https://raw.githubusercontent.com/mitto-sh/mitto-infra/main/agent"
HOME_DIR="${MITTO_AGENT_HOME:-$HOME/.mitto-agent}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but was not found on PATH" >&2
  exit 1
fi

mkdir -p "$HOME_DIR"
cd "$HOME_DIR"

if [ ! -f docker-compose.yml ]; then
  curl -fsSL "$RAW_BASE/docker-compose.yml" -o docker-compose.yml
fi

if [ ! -f .env ]; then
  if [ -n "${MITTO_AGENT_TOKEN:-}" ]; then
    TOKEN="$MITTO_AGENT_TOKEN"
  else
    printf 'Paste the agent token from Mitto (mag_...): '
    read -r TOKEN
  fi
  {
    echo "MITTO_AGENT_TOKEN=$TOKEN"
    [ -n "${MITTO_API_URL:-}" ] && echo "MITTO_API_URL=$MITTO_API_URL"
    [ -n "${MITTO_REALTIME_URL:-}" ] && echo "MITTO_REALTIME_URL=$MITTO_REALTIME_URL"
  } > .env
fi

docker compose pull
docker compose up -d

echo
echo "mitto-agent is running. Follow it with:"
echo "  cd $HOME_DIR && docker compose logs -f agent"
