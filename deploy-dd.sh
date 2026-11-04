#!/usr/bin/env bash
# Build and push the Datadog demo Petclinic (with the "Datadog" menu entry) to
# docker.io/samuelblin/petclinic-dd, and with --k8s deploy it to the current
# Kubernetes context.
# Usage: ./deploy-dd.sh [--k8s] <version>   e.g. ./deploy-dd.sh 1.0.31, ./deploy-dd.sh --k8s 1.0.31
# Env:   PLATFORMS (default linux/amd64,linux/arm64)
set -euo pipefail

IMAGE_REPO="docker.io/samuelblin/petclinic-dd" DATADOG_DEMO=true SCRIPT_NAME="$0" \
  exec "$(dirname "$0")/deploy.sh" "$@"
