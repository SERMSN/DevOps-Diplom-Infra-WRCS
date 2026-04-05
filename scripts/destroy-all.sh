#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_DIR="$ROOT_DIR/infra/bootstrap"
PLATFORM_DIR="$ROOT_DIR/infra/platform"

RED="$(printf '\033[31m')"
GREEN="$(printf '\033[32m')"
YELLOW="$(printf '\033[33m')"
BLUE="$(printf '\033[34m')"
BOLD="$(printf '\033[1m')"
RESET="$(printf '\033[0m')"

step() {
  printf '\n%s==>%s %s%s%s\n' "$BLUE" "$RESET" "$BOLD" "$*" "$RESET"
}

info() {
  printf '%s[i]%s %s\n' "$YELLOW" "$RESET" "$*"
}

success() {
  printf '%s[ok]%s %s\n' "$GREEN" "$RESET" "$*"
}

fail() {
  printf '%s[err]%s %s\n' "$RED" "$RESET" "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Command not found: $1"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

confirm() {
  local answer
  read -r -p "$1 [y/N]: " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]]
}

cleanup_registry_images() {
  local registry_id image_ids raw_json

  cd "$PLATFORM_DIR"
  if ! terraform init -reconfigure >/dev/null 2>&1; then
    info "Platform backend is unavailable or already removed, skipping registry cleanup"
    return 0
  fi
  registry_id="$(terraform output -raw registry_id 2>/dev/null || true)"

  if [[ -z "$registry_id" ]]; then
    info "Registry ID not found in platform outputs, skipping image cleanup"
    return 0
  fi

  info "Registry ID: $registry_id"
  raw_json="$(yc container image list --registry-id "$registry_id" --format json || true)"

  if [[ -z "$raw_json" || "$raw_json" == "[]" ]]; then
    success "Registry is already empty"
    return 0
  fi

  if have_cmd python3; then
    image_ids="$(python3 - <<'PY' <<<"$raw_json"
import json
import sys

data = json.load(sys.stdin)
for item in data:
    image_id = item.get("id")
    if image_id:
        print(image_id)
PY
)"
  else
    image_ids="$(printf '%s\n' "$raw_json" | sed -n 's/.*"id":[[:space:]]*"\([^"]*\)".*/\1/p')"
  fi

  if [[ -z "$image_ids" ]]; then
    success "Registry is already empty"
    return 0
  fi

  while IFS= read -r image_id; do
    [[ -z "$image_id" ]] && continue
    info "Deleting image $image_id"
    yc container image delete "$image_id" >/dev/null
  done <<< "$image_ids"

  success "All registry images deleted"
}

require_cmd terraform
require_cmd kubectl
require_cmd helm
require_cmd yc
require_cmd sed

if ! confirm "This will destroy all diploma resources in Yandex Cloud, including bootstrap. Continue?"; then
  echo "Cancelled."
  exit 0
fi

step "Checking yc authentication"
yc iam create-token >/dev/null || fail "yc authentication failed. Refresh your OAuth token with 'yc config set token ...'"
success "yc authentication is valid"

step "Deleting Kubernetes application and Helm releases if the cluster is still reachable"
kubectl delete -f "$ROOT_DIR/k8s/app/" --ignore-not-found >/dev/null 2>&1 || true
helm uninstall kube-prometheus-stack -n monitoring >/dev/null 2>&1 || true
helm uninstall ingress-nginx -n ingress-nginx >/dev/null 2>&1 || true
kubectl delete namespace app --ignore-not-found >/dev/null 2>&1 || true
kubectl delete namespace monitoring --ignore-not-found >/dev/null 2>&1 || true
kubectl delete namespace ingress-nginx --ignore-not-found >/dev/null 2>&1 || true
success "Kubernetes-side cleanup finished"

step "Deleting container images from registry"
cleanup_registry_images

step "Destroying platform stack"
cd "$PLATFORM_DIR"
if terraform init -reconfigure >/dev/null 2>&1; then
  if terraform destroy -auto-approve; then
    success "Platform stack destroyed"
  else
    info "Platform destroy did not complete cleanly, continuing with bootstrap cleanup"
  fi
else
  info "Platform backend is unavailable or already removed, skipping platform destroy"
fi

step "Destroying bootstrap stack"
cd "$BOOTSTRAP_DIR"
terraform init
terraform destroy -auto-approve
success "Bootstrap stack destroyed"

printf '\n%sDestroy complete%s\n' "$BOLD" "$RESET"
