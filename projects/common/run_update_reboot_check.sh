#!/usr/bin/env bash
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$HOME/.ansible/logs"
LOG_FILE="$LOG_DIR/update_reboot_check.log"

mkdir -p "$LOG_DIR"
cd "$REPO_DIR"

{
  echo "=== $(date -Iseconds) ==="
  # Backstop only: a normal run takes ~1min. SSH transfers can hang forever
  # rather than fail on a broken link (e.g. a path-MTU black hole), so bound
  # the run to keep a bad night from blocking the next scheduled one.
  timeout 30m ansible-playbook \
    -i "$HOME/.ansible/hosts.yml" \
    -e "@$HOME/.ansible/secrets.yml" \
    -e "setupHosts=servers" \
    --vault-password-file "$HOME/.ansible/vault_pass_file" \
    projects/common/update_reboot_check.yml
  exit_code=$?
  if [ "$exit_code" -eq 124 ]; then
    echo "=== TIMED OUT after 30m: $(date -Iseconds) ==="
  else
    echo "=== done: $(date -Iseconds) (exit $exit_code) ==="
  fi
} >> "$LOG_FILE" 2>&1

exit "$exit_code"
