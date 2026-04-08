#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_DIR="$ROOT_DIR/infra/bootstrap"

RED="$(printf '\033[31m')"
GREEN="$(printf '\033[32m')"
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

require_cmd terraform

step "Destroying bootstrap stack"
cd "$BOOTSTRAP_DIR"
retry 3 10 terraform init
retry 3 10 terraform destroy -auto-approve
success "Bootstrap stack destroyed"
