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

## Update packages and reboot if required

Runs `apt` upgrade/autoremove on each host and reboots it if the upgrade left a
`/var/run/reboot-required` marker.

### Requirements

Outside this repo (never committed — see root [CLAUDE.md](../../CLAUDE.md)):

- `~/.ansible/hosts.yml` — real inventory. Each host needs `ansible_become_password:
  "{{ vault_<host>_become_password }}"`.
- `~/.ansible/secrets.yml` — vault-encrypted, holds the `vault_<host>_become_password`
  vars referenced above:
  ```bash
  ansible-vault create ~/.ansible/secrets.yml --vault-password-file ~/.ansible/vault_pass_file
  ```
- `~/.ansible/vault_pass_file` — passphrase that decrypts `secrets.yml` (needed so the
  cron job doesn't have to prompt for one).

### Manual run

```bash
ansible-playbook -i ~/.ansible/hosts.yml -e "@~/.ansible/secrets.yml" --vault-password-file ~/.ansible/vault_pass_file projects/common/update_reboot_check.yml
```

Prompts for which host(s) to target (`vars_prompt`), e.g. `play`, `compose`, or the
`servers` group for both.

### Scheduled run

[`run_update_reboot_check.sh`](run_update_reboot_check.sh) wraps the same command for
both hosts (`setupHosts=servers`, no prompt) and appends output to
`~/.ansible/logs/update_reboot_check.log`. It's invoked daily via the user's crontab
(not tracked in this repo — set up with `crontab -e`):

```cron
0 16 * * * /path/to/ansible-droplet/projects/common/run_update_reboot_check.sh
```
