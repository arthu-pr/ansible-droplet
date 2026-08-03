#!/usr/bin/env bash
#
# Run the update/reboot-check playbook unattended (cron, systemd timer, CI).
#
# Everything is overridable so this works outside the author's setup:
#   ANSIBLE_HOSTS_FILE       inventory                  (default ~/.ansible/hosts.yml)
#   ANSIBLE_SECRETS_FILE     vault-encrypted extra vars (optional)
#   ANSIBLE_VAULT_PASS_FILE  vault password file        (optional)
#   TARGET_HOSTS             host or group              (default: all)
#   RUN_TIMEOUT              hard limit                 (default: 30m)
#   LOG_FILE                 append target
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOSTS_FILE="${ANSIBLE_HOSTS_FILE:-$HOME/.ansible/hosts.yml}"
SECRETS_FILE="${ANSIBLE_SECRETS_FILE:-$HOME/.ansible/secrets.yml}"
VAULT_PASS_FILE="${ANSIBLE_VAULT_PASS_FILE:-$HOME/.ansible/vault_pass_file}"
TARGET_HOSTS="${TARGET_HOSTS:-all}"
RUN_TIMEOUT="${RUN_TIMEOUT:-30m}"
LOG_FILE="${LOG_FILE:-$HOME/.ansible/logs/update_reboot_check.log}"

mkdir -p "$(dirname "$LOG_FILE")"
cd "$REPO_DIR"

# Only pass the optional bits if they exist, so setups without a vault work.
args=(-i "$HOSTS_FILE" -e "setupHosts=$TARGET_HOSTS")
[ -f "$SECRETS_FILE" ] && args+=(-e "@$SECRETS_FILE")
[ -f "$VAULT_PASS_FILE" ] && args+=(--vault-password-file "$VAULT_PASS_FILE")

{
  echo "=== $(date -Iseconds) | hosts=$TARGET_HOSTS ==="
  # Backstop only: a normal run takes ~1min. SSH transfers can hang forever
  # rather than fail on a broken link (e.g. a path-MTU black hole), so bound
  # the run to keep a bad night from blocking the next scheduled one.
  timeout "$RUN_TIMEOUT" ansible-playbook "${args[@]}" \
    projects/common/update_reboot_check.yml
  exit_code=$?
  if [ "$exit_code" -eq 124 ]; then
    echo "=== TIMED OUT after $RUN_TIMEOUT: $(date -Iseconds) ==="
  else
    echo "=== done: $(date -Iseconds) (exit $exit_code) ==="
  fi
} >> "$LOG_FILE" 2>&1

exit "$exit_code"
