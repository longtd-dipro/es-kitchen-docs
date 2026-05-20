#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)/es-kitchen-repository"

declare -A REPO_MAP=(
  ["api"]="es-kitchen-api"
  ["admin"]="es-kitchen-web-admin"
  ["company"]="es-kitchen-web-company"
  ["supplier"]="es-kitchen-web-supplier"
  ["driver"]="es-kitchen-webapp-driver"
  ["private"]="es-kitchen-web-outsource-web-private"
)

DEFAULT_CMD=(
  ["api"]="start:dev"
  ["admin"]="dev"
  ["company"]="dev"
  ["supplier"]="dev"
  ["driver"]="dev"
  ["private"]="dev"
)

SHORT="$1"
CMD="${2:-${DEFAULT_CMD[$SHORT]}}"

if [ -z "$SHORT" ]; then
  echo "Usage: ./run.sh <name> [command]"
  echo ""
  echo "Names:"
  for key in "${!REPO_MAP[@]}"; do
    echo "  $key  →  ${REPO_MAP[$key]}"
  done
  echo ""
  echo "Examples:"
  echo "  ./run.sh api              # npm run start:dev"
  echo "  ./run.sh admin            # npm run dev"
  echo "  ./run.sh company build"
  echo "  ./run.sh api migration:up"
  exit 0
fi

REPO="${REPO_MAP[$SHORT]}"

if [ -z "$REPO" ]; then
  echo "Unknown name: '$SHORT'"
  echo "Valid names: ${!REPO_MAP[*]}"
  exit 1
fi

DIR="$BASE_DIR/$REPO"

if [ ! -d "$DIR" ]; then
  echo "Repo not found: $DIR"
  exit 1
fi

echo ">>> [$REPO] npm run $CMD"
echo ""
npm run "$CMD" --prefix "$DIR"
