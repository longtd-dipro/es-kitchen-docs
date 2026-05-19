#!/bin/bash

REPOS=(
  "es-kitchen-api"
  "es-kitchen-payment-app"
  "es-kitchen-web-admin"
  "es-kitchen-web-company"
)

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

for repo in "${REPOS[@]}"; do
  dir="$BASE_DIR/$repo"
  if [ -d "$dir/.git" ]; then
    echo ">>> Pulling $repo..."
    git -C "$dir" pull
    echo "--- Status ---"
    git -C "$dir" status -s
    echo ""
  else
    echo ">>> SKIP $repo (not a git repo)"
    echo ""
  fi
done
