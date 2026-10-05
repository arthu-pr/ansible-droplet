# Update packages and reboot if required

Runs `apt` upgrade/autoremove on each host and reboots it if the upgrade left a
`/var/run/reboot-required` marker.

## Requirements

These live outside the repo and are never committed:

- **Inventory** (e.g. `~/.ansible/hosts.yml`). If your hosts need a sudo password,
  give each one `ansible_become_password: "{{ vault_<host>_become_password }}"`.
- **`secrets.yml`** — vault-encrypted, holding the `vault_*_become_password` vars
  referenced above:
  ```bash
  ansible-vault create ~/.ansible/secrets.yml --vault-password-file ~/.ansible/vault_pass_file
  ```
- **`vault_pass_file`** — the passphrase that decrypts `secrets.yml`, so an unattended
  run never has to prompt for one.

The vault files are only needed if your hosts require a become password — passwordless
sudo works without them.

## Manual run

```bash
ansible-playbook -i ~/.ansible/hosts.yml -e "@~/.ansible/secrets.yml" --vault-password-file ~/.ansible/vault_pass_file projects/update_reboot_check/update_reboot_check.yml
```

Prompts for which host(s) to target (`vars_prompt`) — a single host, or a group name to
do several at once.

## Scheduled run

Two ways to automate this, with different tradeoffs.

### Recommended: ansible-pull (self-updating)

See [`projects/ansible_pull`](../ansible_pull/README.md) — each host clones this repo and runs
this playbook against *itself* on a systemd timer, no control machine or inbound SSH credential
required. That project's `setup_ansible_pull.yml` defaults `pull_playbook` to
`projects/update_reboot_check/update_reboot_check.yml`.

### Alternative: push from a control machine

[`run_update_reboot_check.sh`](run_update_reboot_check.sh) runs the same playbook with no
prompt and appends to a log, driven by cron or a systemd timer on whichever machine you run it
from. Every path is overridable:

| Variable | Default | Purpose |
| --- | --- | --- |
| `ANSIBLE_HOSTS_FILE` | `~/.ansible/hosts.yml` | Inventory |
| `ANSIBLE_SECRETS_FILE` | `~/.ansible/secrets.yml` | Vault-encrypted extra vars (skipped if absent) |
| `ANSIBLE_VAULT_PASS_FILE` | `~/.ansible/vault_pass_file` | Vault password file (skipped if absent) |
| `TARGET_HOSTS` | `all` | Host or group to target |
| `RUN_TIMEOUT` | `30m` | Hard limit; a hung run is logged as `TIMED OUT` rather than blocking forever |
| `LOG_FILE` | `~/.ansible/logs/update_reboot_check.log` | Append target |

```cron
0 16 * * * /path/to/ansible-droplet/projects/update_reboot_check/run_update_reboot_check.sh
```

To pin it to one group instead of the whole inventory:

```cron
0 16 * * * TARGET_HOSTS=servers /path/to/ansible-droplet/projects/update_reboot_check/run_update_reboot_check.sh
```

Unattended runs authenticate without an `ssh-agent`, so the inventory must point at a
private key file (`ansible_ssh_private_key_file`) — an agent-only key works interactively
but fails under cron with `Permission denied (publickey)`.

Worth it if you want one place to see every host's status, or a host can't reach GitHub
directly. The tradeoff is that machine (and its network) becomes a dependency for maintenance
actually happening — which is the problem ansible-pull avoids.
