#!/usr/bin/env bash
# Build and push the standard Petclinic (no "Datadog" menu entry) on PostgreSQL
# to docker.io/samuelblin/petclinic-postgres, and with --k8s deploy it with a PostgreSQL
# database (springpetclinic-postgres.yaml) to the current Kubernetes context.
# Usage: ./deploy-postgres.sh [--k8s] <version>   e.g. ./deploy-postgres.sh 1.0.31, ./deploy-postgres.sh --k8s 1.0.31
# Env:   PLATFORMS (default linux/amd64,linux/arm64)
set -euo pipefail

IMAGE_REPO="docker.io/samuelblin/petclinic-postgres" DATADOG_DEMO=false DATABASE=postgres SCRIPT_NAME="$0" \
  exec "$(dirname "$0")/deploy.sh" "$@"
