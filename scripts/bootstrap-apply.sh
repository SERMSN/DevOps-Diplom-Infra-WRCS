#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_DIR="$ROOT_DIR/infra/bootstrap"
PLATFORM_DIR="$ROOT_DIR/infra/platform"
BOOTSTRAP_TFVARS="$BOOTSTRAP_DIR/terraform.tfvars"
PLATFORM_TFVARS="$PLATFORM_DIR/terraform.tfvars"

RED="$(printf '\033[31m')"
GREEN="$(printf '\033[32m')"
YELLOW="$(printf '\033[33m')"
BLUE="$(printf '\033[34m')"
BOLD="$(printf '\033[1m')"
RESET="$(printf '\033[0m')"

step() {
  printf '\n%s==>%s %s%s%s\n' "$BLUE" "$RESET" "$BOLD" "$*" "$RESET"
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

    sleep "$delay"
    try=$((try + 1))
  done
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

require_cmd terraform
require_cmd yc

step "Checking bootstrap prerequisites"
require_file "$BOOTSTRAP_TFVARS"
require_file "$PLATFORM_TFVARS"
require_non_placeholder "$BOOTSTRAP_TFVARS" "yc_token"
require_non_placeholder "$BOOTSTRAP_TFVARS" "yc_cloud_id"
require_non_placeholder "$BOOTSTRAP_TFVARS" "yc_folder_id"
require_non_placeholder "$BOOTSTRAP_TFVARS" "tf_state_bucket_name"
yc iam create-token >/dev/null || fail "yc authentication failed. Refresh your OAuth token with 'yc config set token ...'"
success "Bootstrap prerequisites passed"

step "Applying bootstrap stack"
cd "$BOOTSTRAP_DIR"
retry 3 10 terraform init
retry 3 10 terraform apply -auto-approve
render_backend_from_state
success "Bootstrap applied and platform backend rendered"

