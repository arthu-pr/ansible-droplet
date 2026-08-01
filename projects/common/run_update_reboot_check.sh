#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$HOME/.ansible/logs"
LOG_FILE="$LOG_DIR/update_reboot_check.log"

mkdir -p "$LOG_DIR"
cd "$REPO_DIR"

{
  echo "=== $(date -Iseconds) ==="
  ansible-playbook \
    -i "$HOME/.ansible/hosts.yml" \
    -e "@$HOME/.ansible/secrets.yml" \
    -e "setupHosts=servers" \
    --vault-password-file "$HOME/.ansible/vault_pass_file" \
    projects/common/update_reboot_check.yml
  echo "=== done: $(date -Iseconds) ==="
} >> "$LOG_FILE" 2>&1
