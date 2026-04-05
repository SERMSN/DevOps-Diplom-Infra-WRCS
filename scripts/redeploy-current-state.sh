#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_DIR="$ROOT_DIR/infra/bootstrap"
PLATFORM_DIR="$ROOT_DIR/infra/platform"
APP_DIR="$ROOT_DIR/app"
VALUES_FILE="$ROOT_DIR/helm/kube-prometheus-stack/values.yaml"
BOOTSTRAP_TFVARS="$BOOTSTRAP_DIR/terraform.tfvars"
PLATFORM_TFVARS="$PLATFORM_DIR/terraform.tfvars"
TMP_DIR="$(mktemp -d)"

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

check_tfvars() {
  require_file "$BOOTSTRAP_TFVARS"
  require_file "$PLATFORM_TFVARS"

  require_non_placeholder "$BOOTSTRAP_TFVARS" "yc_token"
  require_non_placeholder "$BOOTSTRAP_TFVARS" "yc_cloud_id"
  require_non_placeholder "$BOOTSTRAP_TFVARS" "yc_folder_id"
  require_non_placeholder "$BOOTSTRAP_TFVARS" "tf_state_bucket_name"

  require_non_placeholder "$PLATFORM_TFVARS" "yc_token"
  require_non_placeholder "$PLATFORM_TFVARS" "yc_cloud_id"
  require_non_placeholder "$PLATFORM_TFVARS" "yc_folder_id"
  require_non_placeholder "$PLATFORM_TFVARS" "network_name"
  require_non_placeholder "$PLATFORM_TFVARS" "registry_name"
  require_non_placeholder "$PLATFORM_TFVARS" "kms_key_name"
  require_non_placeholder "$PLATFORM_TFVARS" "cluster_name"
  require_non_placeholder "$PLATFORM_TFVARS" "node_group_name"
}

render_backend_from_state() {
  local access_key secret_key bucket key
  access_key="$(terraform output -raw tf_state_access_key)"
  secret_key="$(terraform output -raw tf_state_secret_key)"
  bucket="$(terraform output -raw tf_state_bucket_name)"
  key="$(terraform output -raw tf_state_backend_key)"

  cat > "$PLATFORM_DIR/backend.tf" <<EOF
terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket                      = "${bucket}"
    key                         = "${key}"
    region                      = "ru-central1"
    access_key                  = "${access_key}"
    secret_key                  = "${secret_key}"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
EOF
}

set_node_group_flag() {
  local tfvars="$PLATFORM_TFVARS"
  if grep -q '^create_node_group' "$tfvars"; then
    sed -i 's/^create_node_group.*/create_node_group = true/' "$tfvars"
  else
    printf '\ncreate_node_group = true\n' >> "$tfvars"
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

apply_app_manifests() {
  local registry_id="$1"
  local ingress_ip="$2"

  sed \
    -e "s|cr.yandex/crp1u84q4sdjf56o68nu/diploma-app:latest|cr.yandex/${registry_id}/diploma-app:latest|g" \
    "$ROOT_DIR/k8s/app/deployment.yaml" > "$TMP_DIR/deployment.yaml"

  cp "$ROOT_DIR/k8s/app/service.yaml" "$TMP_DIR/service.yaml"

  sed \
    -e "s|app\.158\.160\.246\.51\.nip\.io|app.${ingress_ip}.nip.io|g" \
    "$ROOT_DIR/k8s/app/ingress.yaml" > "$TMP_DIR/ingress.yaml"

  kubectl apply -f "$TMP_DIR/deployment.yaml"
  kubectl apply -f "$TMP_DIR/service.yaml"
  kubectl apply -f "$TMP_DIR/ingress.yaml"
}

build_and_push_app() {
  local registry_id="$1"
  yc container registry configure-docker >/dev/null
  docker build -t "cr.yandex/${registry_id}/diploma-app:latest" "$APP_DIR"
  retry 3 10 docker push "cr.yandex/${registry_id}/diploma-app:latest"
}

install_monitoring() {
  local ingress_ip="$1"
  local rendered_values="$TMP_DIR/kube-prometheus-values.yaml"

  sed \
    -e "s|grafana\.158\.160\.246\.51\.nip\.io|grafana.${ingress_ip}.nip.io|g" \
    "$VALUES_FILE" > "$rendered_values"

  kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  retry 3 10 helm repo update >/dev/null
  retry 3 10 helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    -f "$rendered_values"
}

print_summary() {
  local ingress_ip="$1"
  printf '\n%sDeployment complete%s\n' "$BOLD" "$RESET"
  printf '%sGrafana:%s http://grafana.%s.nip.io\n' "$GREEN" "$RESET" "$ingress_ip"
  printf '%sApp:%s     http://app.%s.nip.io\n' "$GREEN" "$RESET" "$ingress_ip"
}

require_cmd terraform
require_cmd yc
require_cmd kubectl
require_cmd helm
require_cmd docker
require_cmd sed

step "Checking local prerequisites"
check_tfvars
yc iam create-token >/dev/null || fail "yc authentication failed. Refresh your OAuth token with 'yc config set token ...'"
success "Prerequisites passed"

step "Applying bootstrap stack"
cd "$BOOTSTRAP_DIR"
retry 3 10 terraform init
retry 3 10 terraform apply -auto-approve
render_backend_from_state
success "Bootstrap applied and backend.tf rendered"

step "Applying platform stack with cluster and node group"
cd "$PLATFORM_DIR"
set_node_group_flag
retry 3 10 terraform init -reconfigure
retry 3 10 terraform apply -auto-approve
success "Platform applied"

CLUSTER_ID="$(terraform output -raw kubernetes_cluster_id)"
REGISTRY_ID="$(terraform output -raw registry_id)"

step "Fetching kubeconfig and verifying cluster access"
retry 3 10 yc managed-kubernetes cluster get-credentials --id "$CLUSTER_ID" --external --force
kubectl get nodes
success "Cluster access is ready"

step "Installing ingress-nginx"
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
retry 3 10 helm repo update >/dev/null
retry 3 10 helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx
success "ingress-nginx installed"

step "Waiting for ingress external IP"
INGRESS_IP="$(wait_for_ingress_ip ingress-nginx ingress-nginx-controller)" || fail "Timed out waiting for ingress external IP"
printf '\n'
success "Ingress external IP: $INGRESS_IP"

step "Installing monitoring stack"
install_monitoring "$INGRESS_IP"
success "Monitoring stack installed"

step "Building and pushing application image"
build_and_push_app "$REGISTRY_ID"
success "Application image pushed to registry"

step "Deploying application manifests"
kubectl create namespace app --dry-run=client -o yaml | kubectl apply -f -
apply_app_manifests "$REGISTRY_ID" "$INGRESS_IP"
success "Application deployed"

step "Final cluster status"
kubectl get nodes
kubectl get pods -A
kubectl get ingress -A

print_summary "$INGRESS_IP"
