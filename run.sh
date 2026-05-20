#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)/es-kitchen-repository"

resolve_repo() {
  case "$1" in
    api)      echo "es-kitchen-api" ;;
    admin)    echo "es-kitchen-web-admin" ;;
    company)  echo "es-kitchen-web-company" ;;
    supplier) echo "es-kitchen-web-supplier" ;;
    driver)   echo "es-kitchen-webapp-driver" ;;
    private)  echo "es-kitchen-web-outsource-web-private" ;;
    *)        echo "" ;;
  esac
}

resolve_default_cmd() {
  case "$1" in
    api) echo "start:dev" ;;
    *)   echo "dev" ;;
  esac
}

SHORT="$1"
CMD="${2:-$(resolve_default_cmd "$SHORT")}"

if [ -z "$SHORT" ]; then
  echo "Usage: ./run.sh <name> [command]"
  echo ""
  echo "Names:"
  echo "  api      →  es-kitchen-api"
  echo "  admin    →  es-kitchen-web-admin"
  echo "  company  →  es-kitchen-web-company"
  echo "  supplier →  es-kitchen-web-supplier"
  echo "  driver   →  es-kitchen-webapp-driver"
  echo "  private  →  es-kitchen-web-outsource-web-private"
  echo ""
  echo "Examples:"
  echo "  ./run.sh api              # npm run start:dev"
  echo "  ./run.sh admin            # npm run dev"
  echo "  ./run.sh company build"
  echo "  ./run.sh api migration:up"
  exit 0
fi

REPO="$(resolve_repo "$SHORT")"

if [ -z "$REPO" ]; then
  echo "Unknown name: '$SHORT'"
  echo "Valid names: api admin company supplier driver private"
  exit 1
fi

DIR="$BASE_DIR/$REPO"

if [ ! -d "$DIR" ]; then
  echo "Repo not found: $DIR"
  exit 1
fi

echo ">>> [$REPO] npm run $CMD"
echo ""
npm --prefix "$DIR" run "$CMD"
