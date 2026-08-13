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

[`run_update_reboot_check.sh`](run_update_reboot_check.sh) runs the same playbook with no
prompt and appends to a log. Every path is overridable, so it works outside the author's
setup:

| Variable | Default | Purpose |
| --- | --- | --- |
| `ANSIBLE_HOSTS_FILE` | `~/.ansible/hosts.yml` | Inventory |
| `ANSIBLE_SECRETS_FILE` | `~/.ansible/secrets.yml` | Vault-encrypted extra vars (skipped if absent) |
| `ANSIBLE_VAULT_PASS_FILE` | `~/.ansible/vault_pass_file` | Vault password file (skipped if absent) |
| `TARGET_HOSTS` | `all` | Host or group to target |
| `RUN_TIMEOUT` | `30m` | Hard limit; a hung run is logged as `TIMED OUT` rather than blocking forever |
| `LOG_FILE` | `~/.ansible/logs/update_reboot_check.log` | Append target |

Invoke it from cron (`crontab -e`) or a systemd timer:

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
