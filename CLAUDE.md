# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Personal Ansible repo for provisioning and maintaining Ubuntu servers (mostly DigitalOcean Droplets): base hardening + user setup, nginx + Let's Encrypt server blocks, package updates/reboots, dev tool installs (zsh/nvm/Zellij/Neovim), and basic monitoring.

## Structure

- `roles/` — shared roles used across projects (`nginx`, `common`).
- `projects/<name>/` — each has its own playbook, `ansible.cfg`, and project-local `roles/`. Project `ansible.cfg` sets `roles_path = roles:../../roles` to combine project-local roles with the shared ones in the repo root.
- `inventories/` — gitignored; contains real host IPs/SSH users. Never assume this directory is tracked or safe to commit.

## Running playbooks

```
ansible-playbook -i ~/.ansible/hosts.yml -e @secrets.yml --ask-vault-pass -K <playbook>.yml
```
`secrets.yml`, `vault_pass_file`, and inventory files are gitignored and never committed.

## Linting

CI runs `ansible-lint -c ansible-lint.yml` (config filename is non-default, must be passed explicitly with `-c`). Key custom rules in `ansible-lint.yml`:
- `var_naming_pattern: ^[a-z_][a-z0-9_]*$`
- `loop_var_prefix: ^(__|{role}_)`
- no `profile` set (defaults apply)

`ansible-lint` is not installed locally in this environment — only runs via the `.github/workflows/ansible-lint.yml` GitHub Action on push/PR to `main`.

## Conventions (differ from ansible defaults)

- Use FQCN for all modules (`ansible.builtin.*`, `community.general.*`, etc.).
- Prefer `vars_prompt` for interactive input (host/username/domain) over vars files — this is the established pattern, not an oversight.
- No `tags:` used anywhere in the repo; don't introduce them unless asked.
- Handlers are named as descriptive actions, e.g. `Restart ssh`, `Restart nginx`.
- Task names are capitalized human-readable phrases, e.g. `Disable root login`.
- No `defaults/` or `vars/` directories in any role — variables are passed via `vars_prompt` or `-e`.

## Known gotchas

- The Certbot/nginx server-block automation (`projects/common/nginx_setup_server_block.yml`) is explicitly WIP/buggy per in-code comments — it can break the Certbot service, and uses a hardcoded placeholder email (`you@example.com`) that still needs to be templated.
- No test framework (no Molecule) — ansible-lint is the only automated check.
- **Unattended runs need their own SSH key.** Interactive access can rely on an `ssh-agent` key that has no private-key file behind it; cron/systemd get no agent socket, so scheduled runs silently failed with `Permission denied (publickey)` while manual runs worked. A dedicated passphrase-less key (`~/.ssh/ansible_droplet_automation`) is deployed alongside existing access on both hosts and pinned in `~/.ansible/hosts.yml` via `ansible_ssh_private_key_file` + `-o IdentitiesOnly=yes -o IdentityAgent=none`.
- **PMTU black hole on some networks (was: mysterious SSH/SFTP hangs).** On a link whose real path MTU is below the interface MTU, small commands work but any bulk transfer hangs forever — TCP keeps retransmitting a full-size packet that can never arrive, and the ICMP `fragmentation needed` reply never gets back. Symptom looks like "Ansible hangs at `Gathering Facts`/module upload". Diagnose with `ping -M do -s <payload> <host>` (payload + 28 = packet size) to find the ceiling, then set the interface MTU to match — scoped to the offending NetworkManager profile so other networks are unaffected:
  ```
  sudo nmcli connection modify <profile> 802-11-wireless.mtu <mtu>
  ```
  Confirmed case: an Android hotspot with path MTU 1464 vs interface 1500. Fixing the MTU took an 80KB transfer from "hangs indefinitely" to 5s, and a full playbook run to 49s. Note this is *not* droplet-specific — the same probe fails against `8.8.8.8`, so test a control host before blaming the servers.
- **KEX hang** (separate from the above): the default `sntrup761x25519-sha512@openssh.com` post-quantum key exchange never completes on some links. Fixed per-host in `~/.ssh/config` by forcing `KexAlgorithms curve25519-sha256`, matched by both alias and IP (Ansible connects via `ansible_host`, which never resolves an alias name).
