#!/usr/bin/env bash
# Build and push the standard Petclinic (no "Datadog" menu entry) to Docker Hub,
# and with --k8s deploy it to the current Kubernetes context.
# See deploy-dd.sh for the Datadog demo, deploy-postgres.sh and
# deploy-dd-postgres.sh for the same variants on PostgreSQL.
# Usage: ./deploy.sh [--k8s] <version>   e.g. ./deploy.sh 1.0.31, ./deploy.sh --k8s 1.0.31
# Env:   PLATFORMS (default linux/amd64,linux/arm64)
set -euo pipefail

# IMAGE_REPO, DATADOG_DEMO, DATABASE and SCRIPT_NAME are set by the deploy-*.sh
# wrappers, do not set them by hand
IMAGE_REPO="${IMAGE_REPO:-docker.io/samuelblin/petclinic}"
DATADOG_DEMO="${DATADOG_DEMO:-false}"
DATABASE="${DATABASE:-h2}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
MANIFEST="springpetclinic.yaml"
DB_MANIFEST="springpetclinic-postgres.yaml"
DB_DEPLOYMENT="petclinic-db"
NAMESPACE="petclinic"
DEPLOYMENT="petclinic"

die() { echo "Error: $*" >&2; exit 1; }

SCRIPT_NAME="${SCRIPT_NAME:-$0}"
usage() { echo "Usage: $SCRIPT_NAME [--k8s] <version>   (e.g. $SCRIPT_NAME 1.0.31)" >&2; exit 1; }

K8S=false
VERSION=""
for arg in "$@"; do
  case "$arg" in
    --k8s) K8S=true ;;
    -*) usage ;;
    *) [ -z "$VERSION" ] || usage; VERSION="$arg" ;;
  esac
done
[ -n "$VERSION" ] || usage
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like 1.0.31, got '$VERSION'"
IMAGE="$IMAGE_REPO:$VERSION"
[[ "$DATADOG_DEMO" =~ ^(true|false)$ ]] || die "DATADOG_DEMO must be true or false, got '$DATADOG_DEMO'"
case "$DATABASE" in
  h2) SPRING_PROFILE="" ;;
  postgres) SPRING_PROFILE="postgres" ;;
  *) die "DATABASE must be h2 or postgres, got '$DATABASE'" ;;
esac

cd "$(dirname "$0")"

CMDS="git podman"
[ "$K8S" = false ] || CMDS="$CMDS kubectl"
for cmd in $CMDS; do
  command -v "$cmd" >/dev/null || die "$cmd not found"
done

# DD_GIT_COMMIT_SHA must match the code in the image and exist on GitHub
[ -z "$(git status --porcelain)" ] || die "working tree is not clean, commit your changes first"
GIT_SHA="$(git rev-parse HEAD)"
git fetch --quiet origin
[ -n "$(git branch -r --contains "$GIT_SHA")" ] || die "commit ${GIT_SHA:0:7} is not pushed, run git push first"

# Never overwrite an image already pushed
podman login --get-login docker.io >/dev/null 2>&1 || die "not logged in, run podman login docker.io"
if ! SEARCH="$(podman search --list-tags --limit 1000 "$IMAGE_REPO" 2>&1)"; then
  # A repository that was never pushed is created by the first push
  grep -q "not known to registry" <<<"$SEARCH" || die "cannot list tags of $IMAGE_REPO: $SEARCH"
  SEARCH=""
fi
TAGS="$(awk 'NR > 1 {print $2}' <<<"$SEARCH")"
! grep -qx "$VERSION" <<<"$TAGS" || die "$IMAGE already exists on Docker Hub, pick a new version"

if [ "$K8S" = true ]; then
  # Check cluster access before the (long) build
  CONTEXT="$(kubectl config current-context)"
  kubectl auth can-i patch deployments -n "$NAMESPACE" >/dev/null 2>&1 \
    || die "cannot deploy to context $CONTEXT (expired credentials? try gcloud auth login)"
  CURRENT="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
    -o jsonpath='{.metadata.labels.tags\.datadoghq\.com/version}' 2>/dev/null || true)"
fi

echo "Image:    $IMAGE ($PLATFORMS)"
echo "Datadog:  demo menu $([ "$DATADOG_DEMO" = true ] && echo enabled || echo disabled)"
echo "Database: $DATABASE"
echo "Commit:   $GIT_SHA"
if [ "$K8S" = true ]; then
  echo "Context:  $CONTEXT, namespace $NAMESPACE (deployed version: ${CURRENT:-none})"
  read -r -p "Build, push and deploy? [y/N] " answer
else
  echo "K8s:      not deployed (add --k8s to deploy)"
  read -r -p "Build and push? [y/N] " answer
fi
[[ "$answer" =~ ^[yY]$ ]] || die "aborted"

echo "==> Building $IMAGE"
# Drop any local manifest or image with this name (not on Docker Hub, checked above)
if podman manifest exists "$IMAGE"; then
  podman manifest rm "$IMAGE" >/dev/null
elif podman image exists "$IMAGE"; then
  podman rmi "$IMAGE" >/dev/null
fi
podman manifest create "$IMAGE" >/dev/null
podman build --platform "$PLATFORMS" --build-arg VERSION="$VERSION" \
  --build-arg DATADOG_DEMO="$DATADOG_DEMO" --build-arg SPRING_PROFILE="$SPRING_PROFILE" \
  --manifest "$IMAGE" .

echo "==> Pushing $IMAGE"
podman manifest push --all --retry 5 --retry-delay 10s "$IMAGE" "docker://$IMAGE"

if [ "$K8S" = false ]; then
  echo "==> $IMAGE pushed (run with --k8s to deploy to Kubernetes)"
  exit 0
fi

echo "==> Deploying to $CONTEXT/$NAMESPACE"
if [ "$DATABASE" = postgres ]; then
  # Start the database first, otherwise the app fails to start and restarts
  kubectl apply -f "$DB_MANIFEST"
  kubectl rollout status deployment/"$DB_DEPLOYMENT" -n "$NAMESPACE" --timeout=5m
fi
sed -e "s|__IMAGE__|$IMAGE|g" -e "s/__GIT_SHA__/$GIT_SHA/g" -e "s/__VERSION__/$VERSION/g" "$MANIFEST" | kubectl apply -f -
kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=5m

echo "==> $IMAGE deployed"
LB_IP="$(kubectl get service petclinic-lb -n "$NAMESPACE" \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
if [ -n "$LB_IP" ]; then
  echo "    http://$LB_IP:8181/"
else
  echo "    External IP pending: kubectl get service petclinic-lb -n $NAMESPACE --watch"
fi
