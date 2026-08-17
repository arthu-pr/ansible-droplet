# Common Projects

## Setup Nginx Server Block

This project is meant to automate the registration of a new domain on a server, with the default configuration on Nginx and Let's Encrypt SSL certificate.

> [!NOTE]
> If running Certbot for the first time, you will need to enter an email address and accept the terms of service.
> See https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-20-04

### Requirements

- You need to have a domain pointing to your server. For example on Digital Ocean, you register a domain and create an A record pointing to your server IP.
  ![Example Domain](assets/new-record-digital-ocean.png)
- You need to create the `www` version of your domain pointing to the same server IP.
  ![www registration](assets/new-record-digital-ocean-2.png)

### Example command

```bash
ansible-playbook -i inventories/hosts.yml -K projects/common/nginx_setup_server_block.yml
```

It will ask you the domain name, which can be given without the `www` (it will be added automatically).

```bash
BECOME password:
Which hosts would you like to use?: test
What is the domain name?: test-ansible.de
```

It then prompts for `server_block_mode` (default `static`, just hit enter for the original
static-file behaviour) and `proxy_port`. Answering `proxy` instead reverse-proxies the domain
to `http://127.0.0.1:<proxy_port>` rather than serving `/var/www/<domain>` — for an app that
listens on its own port and should never be bound to `0.0.0.0` directly (e.g. `pm2-dashboard`).

## Update packages and reboot if required

Runs `apt` upgrade/autoremove on each host and reboots it if the upgrade left a
`/var/run/reboot-required` marker.

### Requirements

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

### Manual run

```bash
ansible-playbook -i ~/.ansible/hosts.yml -e "@~/.ansible/secrets.yml" --vault-password-file ~/.ansible/vault_pass_file projects/common/update_reboot_check.yml
```

Prompts for which host(s) to target (`vars_prompt`) — a single host, or a group name to
do several at once.

### Scheduled run

Two ways to automate this, with different tradeoffs.

#### Recommended: ansible-pull (self-updating)

Each host clones this repo and runs the playbook against *itself* on a systemd timer — no
control machine, no inbound SSH credential, no dependency on any one machine being on and
online.

```bash
ansible-playbook -i ~/.ansible/hosts.yml -e "@~/.ansible/secrets.yml" --vault-password-file ~/.ansible/vault_pass_file -e "setupHosts=<host>" projects/common/setup_ansible_pull.yml
```

Run once per host — after that it's self-sufficient. It installs `roles/ansible_pull`, which
dry-runs (`--check`) before ever applying for real, so a broken commit fails loud in the host's
own journal (`journalctl -u ansible-pull.service`) instead of touching the live system.

> [!IMPORTANT]
> `pull_repo` in `setup_ansible_pull.yml` defaults to the author's repo. If you're running your
> own fork, override it — otherwise your hosts pull *this* repo, not yours:
> `-e pull_repo=https://github.com/<you>/ansible-droplet.git`

**It never tracks `main` directly** — it's pinned to a `deploy` ref (`pull_checkout`), so
ordinary commits don't reach production until deliberately promoted:

```bash
git checkout deploy && git merge main && git push
```

That keeps `main` free for WIP/tutorial commits without them going live automatically. Check a
host's status any time with `systemctl list-timers ansible-pull.timer`.

#### Alternative: push from a control machine

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
0 16 * * * /path/to/ansible-droplet/projects/common/run_update_reboot_check.sh
```

To pin it to one group instead of the whole inventory:

```cron
0 16 * * * TARGET_HOSTS=servers /path/to/ansible-droplet/projects/common/run_update_reboot_check.sh
```

Unattended runs authenticate without an `ssh-agent`, so the inventory must point at a
private key file (`ansible_ssh_private_key_file`) — an agent-only key works interactively
but fails under cron with `Permission denied (publickey)`.

Worth it if you want one place to see every host's status, or a host can't reach GitHub
directly. The tradeoff is that machine (and its network) becomes a dependency for maintenance
actually happening — which is the problem ansible-pull avoids.
