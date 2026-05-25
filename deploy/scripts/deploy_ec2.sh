#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${1:?service name is required}"
IMAGE_URI="${2:?image uri is required}"
DEPLOY_MODE="${3:-stable}"
CONTAINER_PORT="${4:-8080}"
PUBLIC_PORT="${5:-80}"
AWS_REGION="${6:-us-east-1}"

SSH_USER="${SSH_USER:-ec2-user}"
STABLE_HOST="${STABLE_HOST:-}"
CANARY_HOST="${CANARY_HOST:-}"

if [[ -z "$STABLE_HOST" || -z "$CANARY_HOST" ]]; then
  echo "STABLE_HOST and CANARY_HOST must be provided by Jenkins credentials." >&2
  exit 1
fi

case "$DEPLOY_MODE" in
  stable)
    TARGETS=("$STABLE_HOST")
    ;;
  canary)
    TARGETS=("$CANARY_HOST")
    ;;
  *)
    echo "DEPLOY_MODE must be stable or canary." >&2
    exit 1
    ;;
esac

for HOST in "${TARGETS[@]}"; do
  echo "Deploying $SERVICE_NAME to $HOST using image $IMAGE_URI"

  ssh -i /var/lib/jenkins/.ssh/app_ec2_deploy_key \
    -o StrictHostKeyChecking=no \
    "$SSH_USER@$HOST" "bash -s" -- "$SERVICE_NAME" "$IMAGE_URI" "$CONTAINER_PORT" "$PUBLIC_PORT" "$AWS_REGION" <<'REMOTE'
set -euo pipefail

SERVICE_NAME="$1"
IMAGE_URI="$2"
CONTAINER_PORT="$3"
PUBLIC_PORT="$4"
AWS_REGION="$5"
REGISTRY="${IMAGE_URI%%/*}"

if command -v aws >/dev/null 2>&1; then
  aws ecr get-login-password --region "$AWS_REGION" | sudo docker login --username AWS --password-stdin "$REGISTRY"
fi

sudo docker pull "$IMAGE_URI"
sudo docker rm -f "$SERVICE_NAME" >/dev/null 2>&1 || true

sudo docker run -d \
  --restart unless-stopped \
  --name "$SERVICE_NAME" \
  -p "${PUBLIC_PORT}:${CONTAINER_PORT}" \
  "$IMAGE_URI"

sleep 3
sudo docker ps --filter "name=^/${SERVICE_NAME}$"
REMOTE
done
