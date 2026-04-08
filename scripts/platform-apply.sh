#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM_DIR="$ROOT_DIR/infra/platform"
APP_DIR="$ROOT_DIR/app"
VALUES_FILE="$ROOT_DIR/helm/kube-prometheus-stack/values.yaml"
PLATFORM_TFVARS="$PLATFORM_DIR/terraform.tfvars"
TMP_DIR="$(mktemp -d)"
APP_HOST="${APP_HOST:-app.wrcs.su}"
GRAFANA_HOST="${GRAFANA_HOST:-grafana.wrcs.su}"

RED="$(printf '\033[31m')"
GREEN="$(printf '\033[32m')"
YELLOW="$(printf '\033[33m')"
BLUE="$(printf '\033[34m')"
BOLD="$(printf '\033[1m')"
RESET="$(printf '\033[0m')"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

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

require_file() {
  [[ -f "$1" ]] || fail "Required file not found: $1"
}

require_non_placeholder() {
  local file="$1"
  local key="$2"
  grep -Eq "^${key}[[:space:]]*=" "$file" || fail "Missing '${key}' in $file"
  if grep -Eq "^${key}[[:space:]]*=[[:space:]]*\"replace-me\"" "$file"; then
    fail "Value '${key}' in $file is still set to replace-me"
  fi
}

retry() {
  local attempts="$1"
  local delay="$2"
  shift 2

  local try=1
  while true; do
    if "$@"; then
      return 0
    fi

    if (( try >= attempts )); then
      return 1
    fi

    info "Command failed. Retry ${try}/${attempts} after ${delay}s: $*"
    sleep "$delay"
    try=$((try + 1))
  done
}

set_node_group_flag() {
  if grep -q '^create_node_group' "$PLATFORM_TFVARS"; then
    sed -i 's/^create_node_group.*/create_node_group = true/' "$PLATFORM_TFVARS"
  else
    printf '\ncreate_node_group = true\n' >> "$PLATFORM_TFVARS"
  fi
}

wait_for_ingress_ip() {
  local namespace="$1"
  local service="$2"
  local ip=""
  for _ in $(seq 1 60); do
    ip="$(kubectl get svc "$service" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    if [[ -n "$ip" ]]; then
      printf '%s' "$ip"
      return 0
    fi
    printf '.'
    sleep 10
  done
  printf '\n' >&2
  return 1
}

install_monitoring() {
  local grafana_host="$1"
  local rendered_values="$TMP_DIR/kube-prometheus-values.yaml"

  # Keep source values.yaml environment-agnostic and inject runtime host on deploy.
  sed \
    -e "s|__GRAFANA_HOST__|${grafana_host}|g" \
    "$VALUES_FILE" > "$rendered_values"

  kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  retry 3 10 helm repo update >/dev/null
  retry 3 10 helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    -f "$rendered_values"
}

build_and_push_app() {
  local registry_id="$1"
  local grafana_host="$2"
  local build_dir="$ROOT_DIR/.tmp-app-build"

  # Build a temporary context with runtime links to avoid mutating repository files.
  rm -rf "$build_dir"
  mkdir -p "$build_dir"
  cp "$APP_DIR/Dockerfile" "$build_dir/Dockerfile"
  cp "$APP_DIR/nginx.conf" "$build_dir/nginx.conf"
  cp "$APP_DIR/.dockerignore" "$build_dir/.dockerignore"
  sed \
    -e "s|__GRAFANA_HOST__|${grafana_host}|g" \
    "$APP_DIR/index.html" > "$build_dir/index.html"

  yc container registry configure-docker >/dev/null
  yc iam create-token | docker login --username iam --password-stdin cr.yandex >/dev/null
  retry 3 15 docker build -t "cr.yandex/${registry_id}/diploma-app:latest" "$build_dir"
  retry 3 10 docker push "cr.yandex/${registry_id}/diploma-app:latest"

  rm -rf "$build_dir"
}

apply_app_manifests() {
  local registry_id="$1"
  local app_host="$2"

  # Render deployment/ingress from placeholders for current registry and ingress IP.
  sed \
    -e "s|__REGISTRY_ID__|${registry_id}|g" \
    "$ROOT_DIR/k8s/app/deployment.yaml" > "$TMP_DIR/deployment.yaml"

  cp "$ROOT_DIR/k8s/app/service.yaml" "$TMP_DIR/service.yaml"

  sed \
    -e "s|__APP_HOST__|${app_host}|g" \
    "$ROOT_DIR/k8s/app/ingress.yaml" > "$TMP_DIR/ingress.yaml"

  kubectl apply -f "$TMP_DIR/deployment.yaml"
  kubectl apply -f "$TMP_DIR/service.yaml"
  kubectl apply -f "$TMP_DIR/ingress.yaml"
  kubectl rollout status deployment/diploma-app -n app --timeout=5m
}

print_summary() {
  local ingress_ip="$1"
  local app_host="$2"
  local grafana_host="$3"
  printf '\n%sDeployment complete%s\n' "$BOLD" "$RESET"
  printf '%sIngress IP:%s %s\n' "$YELLOW" "$RESET" "$ingress_ip"
  printf '%sGrafana:%s http://%s\n' "$GREEN" "$RESET" "$grafana_host"
  printf '%sApp:%s     http://%s\n' "$GREEN" "$RESET" "$app_host"
}

require_cmd terraform
require_cmd yc
require_cmd kubectl
require_cmd helm
require_cmd docker
require_cmd sed

step "Checking platform prerequisites"
require_file "$PLATFORM_TFVARS"
require_file "$PLATFORM_DIR/backend.tf"
require_non_placeholder "$PLATFORM_TFVARS" "yc_token"
require_non_placeholder "$PLATFORM_TFVARS" "yc_cloud_id"
require_non_placeholder "$PLATFORM_TFVARS" "yc_folder_id"
require_non_placeholder "$PLATFORM_TFVARS" "network_name"
require_non_placeholder "$PLATFORM_TFVARS" "registry_name"
require_non_placeholder "$PLATFORM_TFVARS" "kms_key_name"
require_non_placeholder "$PLATFORM_TFVARS" "cluster_name"
require_non_placeholder "$PLATFORM_TFVARS" "node_group_name"
yc iam create-token >/dev/null || fail "yc authentication failed. Refresh your OAuth token with 'yc config set token ...'"
set_node_group_flag
success "Platform prerequisites passed"

step "Applying platform stack with cluster and node group"
cd "$PLATFORM_DIR"
retry 3 10 terraform init -reconfigure
retry 3 10 terraform apply -auto-approve
success "Platform applied"

local_cluster_id="$(terraform output -raw kubernetes_cluster_id)"
local_registry_id="$(terraform output -raw registry_id)"

step "Fetching kubeconfig and verifying cluster access"
retry 3 10 yc managed-kubernetes cluster get-credentials --id "$local_cluster_id" --external --force
kubectl get nodes >/dev/null
success "Kubeconfig updated and cluster is reachable"

step "Installing ingress-nginx"
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
retry 3 10 helm repo update >/dev/null
retry 3 10 helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx
success "Ingress controller deployed"

step "Waiting for ingress external IP"
ingress_ip="$(wait_for_ingress_ip ingress-nginx ingress-nginx-controller)" || fail "Timed out waiting for ingress external IP"
printf '\n'
success "Ingress external IP acquired: $ingress_ip"

step "Installing monitoring stack"
install_monitoring "$GRAFANA_HOST"
success "Monitoring stack deployed"

step "Building and pushing application image"
build_and_push_app "$local_registry_id" "$GRAFANA_HOST"
success "Application image pushed"

step "Deploying application manifests"
kubectl create namespace app --dry-run=client -o yaml | kubectl apply -f -
apply_app_manifests "$local_registry_id" "$APP_HOST"
success "Application deployed"

print_summary "$ingress_ip" "$APP_HOST" "$GRAFANA_HOST"
