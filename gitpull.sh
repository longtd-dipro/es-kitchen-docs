#!/bin/bash

REPOS=(
  "es-kitchen-api"
  "es-kitchen-payment-app"
  "es-kitchen-web-admin"
  "es-kitchen-web-company"
  "es-kitchen-web-outsource-web-private"
  "es-kitchen-web-supplier"
  "es-kitchen-webapp-driver"
)

BASE_DIR="$(cd "$(dirname "$0")" && pwd)/es-kitchen-repository"

for repo in "${REPOS[@]}"; do
  dir="$BASE_DIR/$repo"
  if [ -d "$dir/.git" ]; then
    echo ">>> [$repo] Checking out develop..."
    git -C "$dir" checkout develop
    echo ">>> [$repo] Pulling..."
    git -C "$dir" pull origin develop
    echo "--- Status ---"
    git -C "$dir" status -s
    echo ""
  else
    echo ">>> SKIP $repo (not a git repo)"
    echo ""
  fi
done
