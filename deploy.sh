#!/usr/bin/env bash
# Build, push and deploy Petclinic to the current Kubernetes context.
# Usage: ./deploy.sh <version>        e.g. ./deploy.sh 1.0.31
# Env:   PLATFORMS (default linux/amd64,linux/arm64)
set -euo pipefail

IMAGE_REPO="docker.io/samuelblin/petclinic"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
MANIFEST="springpetclinic.yaml"
DEPLOYMENT="petclinic"

die() { echo "Error: $*" >&2; exit 1; }

[ $# -eq 1 ] || { echo "Usage: $0 <version>   (e.g. $0 1.0.31)" >&2; exit 1; }
VERSION="$1"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like 1.0.31, got '$VERSION'"
IMAGE="$IMAGE_REPO:$VERSION"

cd "$(dirname "$0")"

for cmd in git podman kubectl; do
  command -v "$cmd" >/dev/null || die "$cmd not found"
done

# DD_GIT_COMMIT_SHA must match the code in the image and exist on GitHub
[ -z "$(git status --porcelain)" ] || die "working tree is not clean, commit your changes first"
GIT_SHA="$(git rev-parse HEAD)"
git fetch --quiet origin
[ -n "$(git branch -r --contains "$GIT_SHA")" ] || die "commit ${GIT_SHA:0:7} is not pushed, run git push first"

# Never overwrite an image already pushed
podman login --get-login docker.io >/dev/null 2>&1 || die "not logged in, run podman login docker.io"
TAGS="$(podman search --list-tags --limit 1000 "$IMAGE_REPO" | awk 'NR > 1 {print $2}')" \
  || die "cannot list tags of $IMAGE_REPO"
! grep -qx "$VERSION" <<<"$TAGS" || die "$IMAGE already exists on Docker Hub, pick a new version"

# Check cluster access before the (long) build
CONTEXT="$(kubectl config current-context)"
kubectl auth can-i patch deployments >/dev/null 2>&1 \
  || die "cannot deploy to context $CONTEXT (expired credentials? try gcloud auth login)"
CURRENT="$(kubectl get deployment "$DEPLOYMENT" \
  -o jsonpath='{.metadata.labels.tags\.datadoghq\.com/version}' 2>/dev/null || true)"

echo "Image:    $IMAGE ($PLATFORMS)"
echo "Commit:   $GIT_SHA"
echo "Context:  $CONTEXT (deployed version: ${CURRENT:-none})"
read -r -p "Build, push and deploy? [y/N] " answer
[[ "$answer" =~ ^[yY]$ ]] || die "aborted"

echo "==> Building $IMAGE"
podman manifest rm "$IMAGE" >/dev/null 2>&1 || true
podman manifest create "$IMAGE" >/dev/null
podman build --platform "$PLATFORMS" --build-arg VERSION="$VERSION" --manifest "$IMAGE" .

echo "==> Pushing $IMAGE"
podman manifest push --all --retry 5 --retry-delay 10s "$IMAGE" "docker://$IMAGE"

echo "==> Deploying to $CONTEXT"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__GIT_SHA__/$GIT_SHA/g" "$MANIFEST" | kubectl apply -f -
kubectl rollout status deployment/"$DEPLOYMENT" --timeout=5m

echo "==> $IMAGE deployed"
