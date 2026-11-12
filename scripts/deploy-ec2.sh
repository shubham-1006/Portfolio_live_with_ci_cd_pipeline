#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE_URI:?IMAGE_URI is required}"
: "${AWS_REGION:?AWS_REGION is required}"

registry="${IMAGE_URI%%/*}"
aws ecr get-login-password --region "$AWS_REGION" |
  docker login --username AWS --password-stdin "$registry"
docker pull "$IMAGE_URI"

if docker container inspect portfolio-previous >/dev/null 2>&1; then
  echo "Found a leftover portfolio-previous container; inspect it before deploying again." >&2
  exit 1
fi

if docker container inspect portfolio-candidate >/dev/null 2>&1; then
  docker rm -f portfolio-candidate
fi

docker run --detach \
  --name portfolio-candidate \
  --publish 127.0.0.1:18080:80 \
  "$IMAGE_URI" >/dev/null

candidate_ready=0
for attempt in $(seq 1 30); do
  if curl --fail --silent http://127.0.0.1:18080/ >/dev/null; then
    candidate_ready=1
    break
  fi
  sleep 2
done

if [[ "$candidate_ready" -ne 1 ]]; then
  docker logs portfolio-candidate
  docker rm -f portfolio-candidate
  echo "The candidate container did not serve HTTP successfully." >&2
  exit 1
fi
docker rm -f portfolio-candidate

had_previous=0
if docker container inspect portfolio >/dev/null 2>&1; then
  docker stop portfolio
  docker rename portfolio portfolio-previous
  had_previous=1
fi

deployment_ready=0
if docker run --detach \
  --name portfolio \
  --restart unless-stopped \
  --publish 80:80 \
  "$IMAGE_URI" >/dev/null; then
  for attempt in $(seq 1 30); do
    if curl --fail --silent http://127.0.0.1/ >/dev/null; then
      deployment_ready=1
      break
    fi
    sleep 2
  done
fi

if [[ "$deployment_ready" -eq 1 ]]; then
  if [[ "$had_previous" -eq 1 ]]; then
    docker rm -f portfolio-previous
  fi
  echo "Deployed and verified $IMAGE_URI"
  exit 0
fi

if docker container inspect portfolio >/dev/null 2>&1; then
  docker rm -f portfolio
fi
if [[ "$had_previous" -eq 1 ]]; then
  docker rename portfolio-previous portfolio
  docker start portfolio
fi

echo "Deployment failed; the previous container was restored when available." >&2
exit 1
